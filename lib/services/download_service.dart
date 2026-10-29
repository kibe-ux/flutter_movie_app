import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../services/movie_download_service.dart';
import 'http_diagnostics.dart';

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

  DownloadService._internal({
    http.Client? client,
    Future<Directory> Function()? documentsDirectoryProvider,
  })  : _client = client ?? http.Client(),
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  DownloadService.forTesting({
    required http.Client client,
    required Future<Directory> Function() documentsDirectoryProvider,
  }) : this._internal(
          client: client,
          documentsDirectoryProvider: documentsDirectoryProvider,
        );

  final http.Client _client;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Map<int, int> _downloadAttempts = {};
  int _nextAttempt = 0;

  bool _isCurrentAttempt(int movieId, int attempt) =>
      !_disposed && _downloadAttempts[movieId] == attempt;

  // Store active downloads
  final Map<int, DownloadItem> _activeDownloads = {};
  final Map<int, StreamSubscription<List<int>>> _activeSubscriptions = {};
  final Map<int, RandomAccessFile> _openFiles = {};
  final Map<int, File> _temporaryFiles = {};
  final Map<int, Completer<void>> _downloadCompletions = {};
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
    required String downloadUrl,
  }) async {
    if (_disposed) return;
    if (_downloadAttempts.containsKey(movieId)) return;
    final attempt = ++_nextAttempt;
    _downloadAttempts[movieId] = attempt;

    try {
      // Check if download already exists
      if (_activeDownloads.containsKey(movieId) &&
          _activeDownloads[movieId]!.status == DownloadStatus.downloading) {
        return; // Already downloading
      }

      final url = downloadUrl.trim();
      if (url.isEmpty) {
        throw ArgumentError.value(
            downloadUrl, 'downloadUrl', 'Must not be empty.');
      }

      // Initialize download item
      _activeDownloads[movieId] = DownloadItem(
        movieId: movieId,
        movieTitle: movieTitle,
        posterPath: posterPath,
        progress: 0.0,
        status: DownloadStatus.downloading,
      );
      _notifyListeners();

      // App-private storage needs no Android storage permission and remains
      // writable on Android 10+ scoped-storage devices.
      final appDir = await _documentsDirectoryProvider();
      if (!_isCurrentAttempt(movieId, attempt)) return;
      final moviesDir = Directory(p.join(appDir.path, 'movies'));
      if (!await moviesDir.exists()) {
        await moviesDir.create(recursive: true);
      }
      if (!_isCurrentAttempt(movieId, attempt)) return;

      // Start the request before choosing an extension because FILMS365 URLs
      // are often tokenized and do not expose one in their path.
      final request = http.Request('GET', Uri.parse(url));
      final response =
          await _client.send(request).timeout(const Duration(seconds: 30));
      if (!_isCurrentAttempt(movieId, attempt)) {
        await response.stream.listen((_) {}).cancel();
        return;
      }
      logHttpDiagnostic(
        endpoint: 'movie-file-transfer',
        status: response.statusCode,
        headers: response.headers,
        fallbackSource: 'download-origin',
      );
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw HttpException(
            'Download request failed (HTTP ${response.statusCode}).');
      }
      final mimeType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (mimeType != null &&
          (mimeType.startsWith('text/') ||
              mimeType.contains('json') ||
              mimeType.contains('xml') ||
              mimeType.contains('bittorrent') ||
              mimeType.contains('mpegurl'))) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException(
            'The provider returned a page or playlist instead of a movie file.');
      }

      // Create a safe filename with an extension inferred from the response.
      final safeTitle =
          movieTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = '${movieId}_${safeTitle.isEmpty ? 'movie' : safeTitle}'
          '${_fileExtension(response.headers['content-type'], url)}';
      final filePath = p.join(moviesDir.path, fileName);
      final contentLength = response.contentLength ?? 0;
      final temporaryFile = File('$filePath.$attempt.part');
      int downloadedBytes = 0;
      final output = await temporaryFile.open(mode: FileMode.write);
      if (!_isCurrentAttempt(movieId, attempt)) {
        await output.close();
        await temporaryFile.delete();
        return;
      }
      final completion = Completer<void>();
      _openFiles[movieId] = output;
      _temporaryFiles[movieId] = temporaryFile;
      _downloadCompletions[movieId] = completion;

      late final StreamSubscription<List<int>> subscription;
      subscription = response.stream.listen(
        (chunk) {
          Future<void> writeChunk() async {
            try {
              if (!_isCurrentAttempt(movieId, attempt)) return;
              await output.writeFrom(chunk);
              downloadedBytes += chunk.length;
              if (contentLength > 0) {
                _updateProgress(
                  movieId,
                  (downloadedBytes / contentLength).clamp(0.0, 1.0),
                );
              }
            } catch (error) {
              await _failStream(movieId, attempt, error);
            }
          }

          // The stream pauses for each asynchronous disk write. A user pause
          // is an additional pause token and remains in effect afterwards.
          subscription.pause(writeChunk());
        },
        onDone: () => unawaited(
          _completeStream(
            movieId: movieId,
            attempt: attempt,
            output: output,
            temporaryFile: temporaryFile,
            destination: File(filePath),
            downloadedBytes: downloadedBytes,
            expectedBytes: contentLength,
          ),
        ),
        onError: (Object error, StackTrace stackTrace) {
          final message = _activeDownloads[movieId]?.status ==
                  DownloadStatus.paused
              ? 'Download connection was interrupted while paused. Please try again.'
              : error.toString();
          unawaited(_failStream(movieId, attempt, StateError(message)));
        },
        cancelOnError: true,
      );
      _activeSubscriptions[movieId] = subscription;
      if (_activeDownloads[movieId]?.status == DownloadStatus.paused) {
        subscription.pause();
      }

      await completion.future;
      if (!_isCurrentAttempt(movieId, attempt)) return;
      _downloadCompletions.remove(movieId);

      if (!_disposed && _activeDownloads.containsKey(movieId)) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
        );
        _notifyListeners();
      }
    } catch (error) {
      if (!_isCurrentAttempt(movieId, attempt)) return;
      _downloadCompletions.remove(movieId);
      await _cleanupDownloadResources(movieId, deleteTemporaryFile: true);
      if (!_disposed && _activeDownloads.containsKey(movieId)) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
          status: DownloadStatus.failed,
          errorMessage: error is HttpException
              ? error.message
              : error is FormatException
                  ? 'The provider did not return a supported movie file.'
                  : error is FileSystemException
                      ? 'The file could not be saved completely. Check available storage and retry.'
                      : 'The download was interrupted. Check your connection and retry.',
        );
        _notifyListeners();
      }
    } finally {
      if (_downloadAttempts[movieId] == attempt) {
        _downloadAttempts.remove(movieId);
      }
    }
  }

  Future<void> _completeStream({
    required int movieId,
    required int attempt,
    required RandomAccessFile output,
    required File temporaryFile,
    required File destination,
    required int downloadedBytes,
    required int expectedBytes,
  }) async {
    final completion = _downloadCompletions[movieId];
    try {
      await output.close();
      if (!_isCurrentAttempt(movieId, attempt)) return;
      if (downloadedBytes == 0) {
        throw const FileSystemException('Download returned an empty file.');
      }
      if (expectedBytes > 0 && downloadedBytes != expectedBytes) {
        throw const FileSystemException(
            'Download ended before the complete file arrived.');
      }
      if (await destination.exists()) await destination.delete();
      await temporaryFile.rename(destination.path);
      _openFiles.remove(movieId);
      _activeSubscriptions.remove(movieId);
      _temporaryFiles.remove(movieId);
      if (completion != null && !completion.isCompleted) completion.complete();
    } catch (error) {
      await _failStream(movieId, attempt, error);
    }
  }

  Future<void> _failStream(int movieId, int attempt, Object error) async {
    if (!_isCurrentAttempt(movieId, attempt)) return;
    final completion = _downloadCompletions[movieId];
    await _cleanupDownloadResources(movieId, deleteTemporaryFile: true);
    if (completion != null && !completion.isCompleted) {
      completion.completeError(error);
    }
  }

  Future<void> _cleanupDownloadResources(
    int movieId, {
    required bool deleteTemporaryFile,
    bool cancelSubscription = true,
  }) async {
    final subscription = _activeSubscriptions.remove(movieId);
    if (cancelSubscription) {
      try {
        await subscription?.cancel();
      } catch (_) {}
    }

    final output = _openFiles.remove(movieId);
    try {
      await output?.close();
    } catch (_) {}

    final temporaryFile = _temporaryFiles.remove(movieId);
    if (deleteTemporaryFile &&
        temporaryFile != null &&
        await temporaryFile.exists()) {
      try {
        await temporaryFile.delete();
      } catch (_) {}
    }
  }

  String _fileExtension(String? contentType, String downloadUrl) {
    final mimeType = contentType?.split(';').first.trim().toLowerCase();
    const extensions = {
      'video/mp4': '.mp4',
      'video/webm': '.webm',
      'video/quicktime': '.mov',
      'video/x-matroska': '.mkv',
      'video/x-msvideo': '.avi',
    };
    final fromMimeType = extensions[mimeType];
    if (fromMimeType != null) return fromMimeType;

    final urlExtension = p.extension(Uri.parse(downloadUrl).path).toLowerCase();
    if (['.mp4', '.webm', '.mov', '.mkv', '.avi'].contains(urlExtension)) {
      return urlExtension;
    }
    return '.mp4';
  }

  /// Pause download
  Future<void> pauseDownload(int movieId) async {
    if (_disposed ||
        _activeDownloads[movieId]?.status != DownloadStatus.downloading) {
      return;
    }

    _activeSubscriptions[movieId]?.pause();
    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.paused,
    );
    _notifyListeners();
  }

  /// Resume download
  Future<void> resumeDownload(int movieId) async {
    if (_disposed ||
        _activeDownloads[movieId]?.status != DownloadStatus.paused) {
      return;
    }

    _activeSubscriptions[movieId]?.resume();
    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.downloading,
    );
    _notifyListeners();
  }

  /// Cancel download
  Future<void> cancelDownload(int movieId) async {
    if (_disposed) return;

    _downloadAttempts.remove(movieId);
    final completion = _downloadCompletions.remove(movieId);
    await _cleanupDownloadResources(movieId, deleteTemporaryFile: true);
    _activeDownloads.remove(movieId);
    _notifyListeners();
    if (completion != null && !completion.isCompleted) {
      completion.completeError(StateError('Download was cancelled.'));
    }
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

  /// Restore saved status after restarting, and clear it if the file vanished.
  Future<void> refreshDownloadStatus({
    required int movieId,
    required String movieTitle,
    String? posterPath,
  }) async {
    if (_disposed || _downloadAttempts.containsKey(movieId)) return;
    try {
      final appDir = await _documentsDirectoryProvider();
      File? savedFile;
      for (final folder in ['movies', 'downloads']) {
        final directory = Directory(p.join(appDir.path, folder));
        if (!await directory.exists()) continue;
        await for (final entry in directory.list()) {
          if (entry is File &&
              p.basename(entry.path).startsWith('${movieId}_') &&
              ['.mp4', '.mkv', '.mov', '.webm', '.avi']
                  .contains(p.extension(entry.path).toLowerCase()) &&
              await entry.length() > 0) {
            savedFile = entry;
            break;
          }
        }
        if (savedFile != null) break;
      }
      if (_disposed || _downloadAttempts.containsKey(movieId)) return;
      if (savedFile != null) {
        _activeDownloads[movieId] = DownloadItem(
          movieId: movieId,
          movieTitle: movieTitle,
          posterPath: posterPath,
          progress: 1,
          status: DownloadStatus.completed,
        );
        _notifyListeners();
      } else if (_activeDownloads[movieId]?.status ==
          DownloadStatus.completed) {
        _activeDownloads.remove(movieId);
        _notifyListeners();
      }
    } on FileSystemException {
      // An inaccessible directory does not prove a saved movie was deleted.
    }
  }

  /// Get list of downloaded movies
  Future<List<DownloadedMovie>> getDownloadedMovies() async {
    try {
      final appDir = await _documentsDirectoryProvider();
      final files = <FileSystemEntity>[];
      for (final folder in ['movies', 'downloads']) {
        final directory = Directory(p.join(appDir.path, folder));
        if (await directory.exists()) {
          files.addAll(await directory
              .list()
              .where((entity) => entity is File)
              .toList());
        }
      }
      final movies = <DownloadedMovie>[];

      for (final file in files) {
        if (file is File &&
            ['.mp4', '.mkv', '.mov', '.webm', '.avi']
                .contains(p.extension(file.path).toLowerCase())) {
          final stat = await file.stat();
          if (stat.size == 0) continue;
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
        final match = RegExp(r'^(\d+)_').firstMatch(p.basename(filePath));
        final movieId = int.tryParse(match?.group(1) ?? '');
        if (movieId != null &&
            _activeDownloads[movieId]?.status == DownloadStatus.completed) {
          _activeDownloads.remove(movieId);
          _notifyListeners();
        }
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
    final savedTitle = RegExp(r'^\d+_(.+)$').firstMatch(base);
    if (savedTitle != null) return savedTitle.group(1)!.replaceAll('_', ' ');
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
    _downloadAttempts.clear();
    _client.close();
    for (final completion in _downloadCompletions.values) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('Download service was closed.'));
      }
    }
    _downloadCompletions.clear();
    for (final subscription in _activeSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final output in _openFiles.values) {
      unawaited(output.close());
    }
    _activeDownloads.clear();
    if (!_downloadController.isClosed) {
      _downloadController.close();
    }
  }
}
