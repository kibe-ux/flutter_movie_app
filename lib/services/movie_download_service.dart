import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/download_task.dart';
import '../models/movie.dart';

class DownloadedMovie {
  const DownloadedMovie({
    required this.title,
    required this.path,
    required this.size,
    required this.formattedSize,
    required this.modifiedAt,
  });

  final String title;
  final String path;
  final int size;
  final String formattedSize;
  final DateTime modifiedAt;
}

class MovieDownloadService {
  MovieDownloadService._internal();
  static final MovieDownloadService _instance = MovieDownloadService._internal();
  factory MovieDownloadService() => _instance;

  final StreamController<Map<String, DownloadTask>> _downloadController =
      StreamController<Map<String, DownloadTask>>.broadcast();
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, _ActiveDownload> _activeDownloads = {};
  final http.Client _apiClient = http.Client();

  Stream<Map<String, DownloadTask>> get downloadTasksStream =>
      _downloadController.stream;
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  String get _baseUrl {
    final raw = dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL'] ?? 'http://10.0.2.2:3000';
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  String get _apiKey => dotenv.env['MOVIE_DOWNLOAD_API_KEY'] ?? 'dev-api-key';

  Future<List<Movie>> fetchMovies() async {
    final response = await _withRetry(
      () => _apiClient.get(Uri.parse('$_baseUrl/api/movies'), headers: _authHeaders),
    );
    _ensureSuccess(response, endpoint: '/api/movies');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final movies = (decoded['movies'] as List<dynamic>? ?? [])
        .map((item) => Movie.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
    return movies;
  }

  Future<Movie> fetchMovieDetails(String id) async {
    final response = await _withRetry(
      () => _apiClient.get(Uri.parse('$_baseUrl/api/movies/$id'), headers: _authHeaders),
    );
    _ensureSuccess(response, endpoint: '/api/movies/$id');
    return Movie.fromJson((jsonDecode(response.body) as Map).cast<String, dynamic>());
  }

  Future<String> requestSignedDownloadUrl({
    required String movieId,
    required String quality,
  }) async {
    final response = await _withRetry(
      () => _apiClient.post(
        Uri.parse('$_baseUrl/api/download/request'),
        headers: _jsonHeaders,
        body: jsonEncode({'movieId': movieId, 'quality': quality}),
      ),
    );
    _ensureSuccess(response, endpoint: '/api/download/request');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final url = decoded['downloadUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Invalid signed download URL from server.');
    }
    return url;
  }

  DownloadTask? getTask(String movieId, String quality) {
    return _tasks[_taskId(movieId, quality)];
  }

  Future<void> startDownload({
    required Movie movie,
    required String quality,
  }) async {
    final qualityInfo = movie.qualities[quality];
    if (qualityInfo == null) {
      throw Exception('Quality $quality is not available for ${movie.title}.');
    }

    await _ensureStoragePermission();
    final taskId = _taskId(movie.id, quality);
    final savePath = await _buildLocalPath(movie, quality, qualityInfo.path);
    final file = File(savePath);

    int existingBytes = file.existsSync() ? await file.length() : 0;
    if (qualityInfo.size > 0 && existingBytes > qualityInfo.size) {
      await file.delete();
      existingBytes = 0;
    }

    _tasks[taskId] = DownloadTask(
      id: taskId,
      movieId: movie.id,
      movieTitle: movie.title,
      movieYear: movie.year,
      quality: quality,
      savePath: savePath,
      downloadedBytes: existingBytes,
      totalBytes: qualityInfo.size,
      progress: qualityInfo.size > 0 ? existingBytes / qualityInfo.size : 0,
      status: DownloadTaskStatus.downloading,
    );
    _emitTasks();

    if (_activeDownloads.containsKey(taskId)) return;
    unawaited(_resumeTaskInternal(taskId));
  }

  Future<void> pauseDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    await _stopActiveDownload(taskId);
    final downloadedBytes = await _safeFileLength(task.savePath);
    final total = task.totalBytes;
    _tasks[taskId] = task.copyWith(
      status: DownloadTaskStatus.paused,
      downloadedBytes: downloadedBytes,
      progress: total > 0 ? downloadedBytes / total : task.progress,
      clearError: true,
    );
    _emitTasks();
  }

  Future<void> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status == DownloadTaskStatus.completed) return;
    if (_activeDownloads.containsKey(taskId)) return;

    _tasks[taskId] = task.copyWith(
      status: DownloadTaskStatus.downloading,
      clearError: true,
    );
    _emitTasks();
    unawaited(_resumeTaskInternal(taskId));
  }

  Future<void> cancelDownload(String taskId, {bool deletePartial = true}) async {
    final task = _tasks[taskId];
    if (task == null) return;

    await _stopActiveDownload(taskId);
    if (deletePartial) {
      final file = File(task.savePath);
      if (file.existsSync()) {
        await file.delete();
      }
    }

    _tasks[taskId] = task.copyWith(
      status: DownloadTaskStatus.canceled,
      progress: 0,
      downloadedBytes: 0,
      clearError: true,
    );
    _emitTasks();
  }

  Future<List<DownloadedMovie>> getDownloadedMovies() async {
    final directory = await _downloadDirectory();
    if (!directory.existsSync()) {
      return const [];
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) {
          final ext = p.extension(file.path).toLowerCase();
          return ext == '.mp4' || ext == '.mkv' || ext == '.mov' || ext == '.webm' || ext == '.avi';
        })
        .toList();

    final output = <DownloadedMovie>[];
    for (final file in files) {
      final stat = await file.stat();
      output.add(
        DownloadedMovie(
          title: _titleFromFilePath(file.path),
          path: file.path,
          size: stat.size,
          formattedSize: _formatBytes(stat.size),
          modifiedAt: stat.modified,
        ),
      );
    }

    output.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return output;
  }

  Future<void> deleteDownloadedMovie(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  void dispose() {
    for (final taskId in _activeDownloads.keys.toList()) {
      unawaited(_stopActiveDownload(taskId));
    }
    _apiClient.close();
    _downloadController.close();
  }

  Future<void> _resumeTaskInternal(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    try {
      final signedUrl = await requestSignedDownloadUrl(
        movieId: task.movieId,
        quality: task.quality,
      );
      await _downloadFromUrl(taskId: taskId, signedUrl: signedUrl);
    } catch (error) {
      final current = _tasks[taskId];
      if (current == null) return;
      if (current.status == DownloadTaskStatus.paused ||
          current.status == DownloadTaskStatus.canceled ||
          current.status == DownloadTaskStatus.completed) {
        return;
      }

      _tasks[taskId] = current.copyWith(
        status: DownloadTaskStatus.failed,
        errorMessage: error.toString(),
      );
      _emitTasks();
    }
  }

  Future<void> _downloadFromUrl({
    required String taskId,
    required String signedUrl,
  }) async {
    final task = _tasks[taskId];
    if (task == null) return;

    final file = File(task.savePath);
    await file.parent.create(recursive: true);

    int downloadedBytes = await _safeFileLength(task.savePath);

    final request = http.Request('GET', Uri.parse(signedUrl));
    request.headers['x-api-key'] = _apiKey;
    if (downloadedBytes > 0) {
      request.headers['Range'] = 'bytes=$downloadedBytes-';
    }

    final client = http.Client();
    final response = await client.send(request);
    if (response.statusCode != 200 && response.statusCode != 206) {
      client.close();
      throw Exception('Download failed (${response.statusCode}).');
    }

    final bool append = response.statusCode == 206 && downloadedBytes > 0;
    if (!append && downloadedBytes > 0) {
      await file.writeAsBytes(const <int>[], mode: FileMode.write);
      downloadedBytes = 0;
    }

    int totalBytes = task.totalBytes;
    if (response.statusCode == 206) {
      totalBytes = _parseTotalFromContentRange(response.headers['content-range']) ??
          (downloadedBytes + (response.contentLength ?? 0));
    } else {
      totalBytes = response.contentLength ?? totalBytes;
    }

    _tasks[taskId] = task.copyWith(
      status: DownloadTaskStatus.downloading,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      progress: totalBytes > 0 ? downloadedBytes / totalBytes : 0,
      clearError: true,
    );
    _emitTasks();

    final sink = file.openWrite(mode: append ? FileMode.append : FileMode.write);
    late final StreamSubscription<List<int>> subscription;

    subscription = response.stream.listen(
      (chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        final current = _tasks[taskId];
        if (current == null) return;

        _tasks[taskId] = current.copyWith(
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          progress: totalBytes > 0 ? downloadedBytes / totalBytes : current.progress,
        );
        _emitTasks();
      },
      onError: (Object error, StackTrace stackTrace) async {
        await sink.close();
        client.close();
        _activeDownloads.remove(taskId);

        final current = _tasks[taskId];
        if (current == null) return;
        if (current.status == DownloadTaskStatus.paused ||
            current.status == DownloadTaskStatus.canceled) {
          return;
        }

        _tasks[taskId] = current.copyWith(
          status: DownloadTaskStatus.failed,
          errorMessage: error.toString(),
        );
        _emitTasks();
      },
      onDone: () async {
        await sink.close();
        client.close();
        _activeDownloads.remove(taskId);

        final current = _tasks[taskId];
        if (current == null) return;
        if (current.status == DownloadTaskStatus.paused ||
            current.status == DownloadTaskStatus.canceled) {
          return;
        }

        final actualBytes = await _safeFileLength(current.savePath);
        final completedTotal = current.totalBytes > 0 ? current.totalBytes : actualBytes;
        _tasks[taskId] = current.copyWith(
          status: DownloadTaskStatus.completed,
          downloadedBytes: actualBytes,
          totalBytes: completedTotal,
          progress: 1,
          clearError: true,
        );
        _emitTasks();
      },
      cancelOnError: true,
    );

    _activeDownloads[taskId] = _ActiveDownload(
      client: client,
      sink: sink,
      subscription: subscription,
    );
  }

  Future<void> _stopActiveDownload(String taskId) async {
    final active = _activeDownloads.remove(taskId);
    if (active == null) return;

    try {
      await active.subscription.cancel();
    } catch (_) {}
    try {
      await active.sink.flush();
    } catch (_) {}
    try {
      await active.sink.close();
    } catch (_) {}
    active.client.close();
  }

  Future<void> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return;

    final storage = await Permission.storage.request();
    if (storage.isGranted) return;

    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return;

    final videos = await Permission.videos.request();
    if (videos.isGranted) return;

    throw Exception('Storage permission denied. Please allow file access.');
  }

  Future<Directory> _downloadDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'downloads'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _buildLocalPath(Movie movie, String quality, String remotePath) async {
    final dir = await _downloadDirectory();
    final ext = p.extension(remotePath).isEmpty ? '.mp4' : p.extension(remotePath);
    final safeTitle = movie.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '.');
    final fileName = '$safeTitle.${movie.year}.${quality.toLowerCase()}$ext';
    return p.join(dir.path, fileName);
  }

  Future<int> _safeFileLength(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return 0;
    return file.length();
  }

  int? _parseTotalFromContentRange(String? header) {
    if (header == null || !header.contains('/')) return null;
    final suffix = header.split('/').last.trim();
    return int.tryParse(suffix);
  }

  Map<String, String> get _authHeaders => {'x-api-key': _apiKey};

  Map<String, String> get _jsonHeaders => {
        'x-api-key': _apiKey,
        'Content-Type': 'application/json',
      };

  Future<http.Response> _withRetry(
    Future<http.Response> Function() operation, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation().timeout(const Duration(seconds: 45));
      } catch (error) {
        lastError = error;
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: attempt * 400));
      }
    }
    throw Exception('Request failed: $lastError');
  }

  void _ensureSuccess(http.Response response, {required String endpoint}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Request to $endpoint failed (${response.statusCode}): ${response.body}');
  }

  String _taskId(String movieId, String quality) => '$movieId::$quality'.toLowerCase();

  String _titleFromFilePath(String filePath) {
    final base = p.basenameWithoutExtension(filePath);
    final match = RegExp(r'^(.*)\.(\d{4})\.(\d{3,4}p?)$', caseSensitive: false).firstMatch(base);
    if (match == null) {
      return base.replaceAll('.', ' ');
    }
    final title = (match.group(1) ?? '').replaceAll('.', ' ').trim();
    final year = match.group(2) ?? '';
    return '$title ($year)';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    final amount = value < 10 && index > 0 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
    return '$amount ${units[index]}';
  }

  void _emitTasks() {
    if (!_downloadController.isClosed) {
      _downloadController.add(Map<String, DownloadTask>.from(_tasks));
    }
  }
}

class _ActiveDownload {
  _ActiveDownload({
    required this.client,
    required this.sink,
    required this.subscription,
  });

  final http.Client client;
  final IOSink sink;
  final StreamSubscription<List<int>> subscription;
}
