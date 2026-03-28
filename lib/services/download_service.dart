import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/movie_download_service.dart';

/// Download status enum
enum DownloadStatus { idle, downloading, paused, completed, failed }

/// Download item model
class DownloadItem {
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage;

  DownloadItem({
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
  });

  DownloadItem copyWith({
    int? movieId,
    String? movieTitle,
    String? posterPath,
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadItem(
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      posterPath: posterPath ?? this.posterPath,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Download Service - Ready for your friend's API integration
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();

  factory DownloadService() {
    return _instance;
  }

  DownloadService._internal();

  // Store active downloads
  final Map<int, DownloadItem> _activeDownloads = {};
  final StreamController<Map<int, DownloadItem>> _downloadController =
      StreamController<Map<int, DownloadItem>>.broadcast();

  bool _disposed = false;

  /// Get stream of downloads for UI updates
  Stream<Map<int, DownloadItem>> get downloadsStream =>
      _downloadController.stream;

  /// Get all active downloads
  Map<int, DownloadItem> get activeDownloads => Map.from(_activeDownloads);

  /// Start downloading a movie
  Future<void> downloadMovie({
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    String? downloadUrl,
  }) async {
    if (_disposed) return;

    try {
      // Check if download already exists
      if (_activeDownloads.containsKey(movieId) &&
          _activeDownloads[movieId]!.status == DownloadStatus.downloading) {
        return; // Already downloading
      }

      // For demo purposes, use a sample video URL if no downloadUrl provided
      final url = downloadUrl ??
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

      // Initialize download item
      _activeDownloads[movieId] = DownloadItem(
        movieId: movieId,
        movieTitle: movieTitle,
        posterPath: posterPath,
        progress: 0.0,
        status: DownloadStatus.downloading,
      );
      _notifyListeners();

      // Get app documents directory for storing downloads
      final appDir = await getApplicationDocumentsDirectory();
      final moviesDir = Directory(p.join(appDir.path, 'movies'));
      if (!await moviesDir.exists()) {
        await moviesDir.create(recursive: true);
      }

      // Create safe filename
      final safeTitle =
          movieTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = '${movieId}_$safeTitle.mp4';
      final filePath = p.join(moviesDir.path, fileName);

      // Start download
      final request = http.Request('GET', Uri.parse(url));
      final response =
          await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      if (contentLength == 0) {
        throw Exception('Invalid content length');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      int downloadedBytes = 0;

      await response.stream.listen(
        (chunk) {
          if (_disposed || !_activeDownloads.containsKey(movieId)) {
            sink.close();
            return;
          }
          sink.add(chunk);
          downloadedBytes += chunk.length;
          final progress = downloadedBytes / contentLength;
          _updateProgress(movieId, progress.clamp(0.0, 1.0));
        },
        onDone: () async {
          await sink.close();
          if (!_disposed && _activeDownloads.containsKey(movieId)) {
            _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
              status: DownloadStatus.completed,
              progress: 1.0,
            );
            _notifyListeners();
          }
        },
        onError: (error) async {
          await sink.close();
          if (!_disposed && _activeDownloads.containsKey(movieId)) {
            _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
              status: DownloadStatus.failed,
              errorMessage: error.toString(),
            );
            _notifyListeners();
          }
        },
        cancelOnError: true,
      ).asFuture();
    } catch (error) {
      if (_activeDownloads.containsKey(movieId)) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error.toString(),
        );
        _notifyListeners();
      }
    }
  }

  /// Pause download
  Future<void> pauseDownload(int movieId) async {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.paused,
    );
    _notifyListeners();
  }

  /// Resume download
  Future<void> resumeDownload(int movieId) async {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.downloading,
    );
    _notifyListeners();
  }

  /// Cancel download
  Future<void> cancelDownload(int movieId) async {
    if (_disposed) return;

    _activeDownloads.remove(movieId);
    _notifyListeners();
  }

  /// Update download progress
  void _updateProgress(int movieId, double progress) {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      progress: progress,
    );
    _notifyListeners();
  }

  /// Notify listeners of changes
  void _notifyListeners() {
    if (!_disposed && !_downloadController.isClosed) {
      _downloadController.add(Map.from(_activeDownloads));
    }
  }

  /// Get download status for a specific movie
  DownloadStatus? getDownloadStatus(int movieId) {
    return _activeDownloads[movieId]?.status;
  }

  /// Get list of downloaded movies
  Future<List<DownloadedMovie>> getDownloadedMovies() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final moviesDir = Directory(p.join(appDir.path, 'movies'));

      if (!await moviesDir.exists()) {
        return [];
      }

      final files =
          await moviesDir.list().where((entity) => entity is File).toList();
      final movies = <DownloadedMovie>[];

      for (final file in files) {
        if (file is File &&
            ['.mp4', '.mkv', '.mov', '.webm', '.avi']
                .contains(p.extension(file.path).toLowerCase())) {
          final stat = await file.stat();
          final title = _titleFromFilePath(file.path);
          movies.add(DownloadedMovie(
            title: title,
            path: file.path,
            size: stat.size,
            formattedSize: _formatBytes(stat.size),
            modifiedAt: stat.modified,
          ));
        }
      }

      movies.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return movies;
    } catch (e) {
      return [];
    }
  }

  /// Delete downloaded movie
  Future<bool> deleteDownloadedMovie(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Helper method to extract title from file path
  String _titleFromFilePath(String filePath) {
    final base = p.basenameWithoutExtension(filePath);
    final match = RegExp(r'^(.*)\.(\d{4})\.(\d{3,4}p?)$', caseSensitive: false)
        .firstMatch(base);
    if (match == null) {
      return base.replaceAll('.', ' ');
    }
    final title = (match.group(1) ?? '').replaceAll('.', ' ').trim();
    final year = match.group(2) ?? '';
    return '$title ($year)';
  }

  /// Helper method to format bytes
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }
    final amount = value < 10 && index > 0
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(0);
    return '$amount ${units[index]}';
  }

  /// Proper cleanup - must be called on app exit
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _activeDownloads.clear();
    if (!_downloadController.isClosed) {
      _downloadController.close();
    }
  }
}
