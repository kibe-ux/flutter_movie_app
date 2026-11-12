import '../models/download_item.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'download_queue_store.dart';
import 'download_background_service.dart';
import 'download_source_request.dart';
import 'validated_download_response.dart';

import '../models/downloaded_movie.dart';
import 'http_diagnostics.dart';
import 'wambesha_api_service.dart'
    show WambeshaSourceUnavailable, WambeshaRequestException;

/// Serial downloads with private recovery checkpoints and Android foreground work.
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();

  factory DownloadService() {
    return _instance;
  }

  DownloadService._internal({
    http.Client? client,
    Future<Directory> Function()? documentsDirectoryProvider,
    DownloadQueueStore? queueStore,
    DownloadBackgroundService? backgroundService,
    String? Function()? ownerProvider,
    bool persistQueue = true,
  })  : _client = client ?? http.Client(),
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        _queueStore = persistQueue
            ? queueStore ??
                DownloadQueueStore(documentsDirectoryProvider ??
                    getApplicationDocumentsDirectory)
            : null,
        _background = backgroundService ?? DownloadBackgroundService(),
        _owner =
            ownerProvider ?? (() => FirebaseAuth.instance.currentUser?.uid) {
    _background.initialize();
    _background.onControl = (action, id) async {
      if (action == 'pauseAll') {
        if (_running != null) await pauseDownload(_running!.movieId);
      } else if (id != null && action == 'pause') {
        await pauseDownload(id);
      } else if (id != null && action == 'cancel') {
        await cancelDownload(id);
      }
    };
  }

  DownloadService.forTesting({
    required http.Client client,
    required Future<Directory> Function() documentsDirectoryProvider,
    DownloadQueueStore? queueStore,
    DownloadBackgroundService? backgroundService,
    String? Function()? ownerProvider,
  }) : this._internal(
          client: client,
          documentsDirectoryProvider: documentsDirectoryProvider,
          queueStore: queueStore,
          persistQueue: queueStore != null,
          backgroundService:
              backgroundService ?? DownloadBackgroundService(enabled: false),
          ownerProvider: ownerProvider ?? (() => null),
        );

  final http.Client _client;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final DownloadQueueStore? _queueStore;
  final DownloadBackgroundService _background;
  final String? Function() _owner;
  Future<void>? _initialization;
  bool _initialized = false;
  bool _recoveryPaused = false;
  DateTime _lastNotification = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCheckpoint = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<int, Future<void>> _writesInFlight = {};
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
  final Map<int, _QueuedDownload> _requests = {};
  final Map<int, Stopwatch> _transferClocks = {};
  _QueuedDownload? _running;
  final StreamController<Map<int, DownloadItem>> _downloadController =
      StreamController<Map<int, DownloadItem>>.broadcast();

  bool _disposed = false;

  /// Get stream of downloads for UI updates
  Stream<Map<int, DownloadItem>> get downloadsStream =>
      _downloadController.stream;

  /// Get all active downloads
  Map<int, DownloadItem> get activeDownloads => Map.from(_activeDownloads);
  bool get recoveryPending => _recoveryPaused;

  Future<void> initialize() => _initialization ??= _restoreQueue();

  Future<void> _restoreQueue() async {
    final snapshot = await _queueStore?.load();
    if (_disposed) return;
    if (snapshot != null && snapshot['owner'] == _owner()) {
      final records = snapshot['jobs'];
      for (final raw in records is List ? records.take(500) : const []) {
        try {
          final request =
              _QueuedDownload.fromJson(Map<String, dynamic>.from(raw as Map));
          if (request.owner != _owner()) continue;
          if (_requests.containsKey(request.movieId)) continue;
          final root = await _documentsDirectoryProvider();
          final partial =
              File(p.join(root.path, 'movies', request.partialName));
          request.downloadedBytes =
              await partial.exists() ? await partial.length() : 0;
          _requests[request.movieId] = request;
          _activeDownloads[request.movieId] = DownloadItem(
              movieId: request.movieId,
              movieTitle: request.title,
              posterPath: request.poster,
              downloadedBytes: request.downloadedBytes,
              totalBytes: request.totalBytes,
              progress: request.totalBytes > 0
                  ? (request.downloadedBytes / request.totalBytes).clamp(0, 1)
                  : 0,
              status: _requests.length == 1
                  ? DownloadStatus.paused
                  : DownloadStatus.queued);
        } on FormatException {
          /* Invalid record does not invalidate other jobs. */
        } on TypeError {
          /* Ignore unsupported records. */
        } on FileSystemException {
          /* An unreadable partial cannot be resumed. */
        }
      }
    }
    _recoveryPaused = _requests.isNotEmpty;
    _initialized = true;
    _notifyListeners();
  }

  Future<void> _checkpoint() async {
    if (_queueStore == null || _disposed) return;
    await _queueStore.save({
      'owner': _owner(),
      'jobs': _requests.values.map((request) => request.toJson()).toList()
    });
  }

  /// Useful when the UI closes, and for checking durable queue recovery.
  Future<void> flushQueue() async {
    await _checkpoint();
    await _queueStore?.flushed;
  }

  /// Enqueue once; duplicate taps return immediately without another transfer.
  Future<void> downloadMovie({
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    required String downloadUrl,
    Future<String> Function()? downloadUrlProvider,
    DownloadSourceRequest? sourceRequest,
  }) {
    if (_disposed) return Future.value();
    if (_queueStore != null && !_initialized) {
      return initialize().then((_) => downloadMovie(
          movieId: movieId,
          movieTitle: movieTitle,
          posterPath: posterPath,
          downloadUrl: downloadUrl,
          downloadUrlProvider: downloadUrlProvider,
          sourceRequest: sourceRequest));
    }
    final existing = _requests[movieId];
    if (existing != null) return Future.value();
    final request = _QueuedDownload(
        movieId, movieTitle, posterPath, downloadUrl, downloadUrlProvider,
        sourceRequest: sourceRequest, owner: _owner());
    _requests[movieId] = request;
    _activeDownloads[movieId] = DownloadItem(
        movieId: movieId,
        movieTitle: movieTitle,
        posterPath: posterPath,
        status: DownloadStatus.queued);
    _notifyListeners();
    _startNext();
    unawaited(_checkpoint().catchError((Object _) {}));
    return request.done.future;
  }

  int? queuePosition(int movieId) {
    final waiting =
        _requests.values.where((request) => request != _running).toList();
    if (_running == null && _recoveryPaused && waiting.isNotEmpty) {
      waiting.removeAt(0);
    }
    final index = waiting.indexWhere((request) => request.movieId == movieId);
    return index < 0 ? null : index + 1;
  }

  void _startNext() {
    if (_disposed || _recoveryPaused || _running != null || _requests.isEmpty) {
      return;
    }
    final request = _requests.values.first;
    _running = request;
    unawaited(_runQueued(request));
  }

  Future<void> _runQueued(_QueuedDownload request) async {
    try {
      await _checkpoint();
      if (_disposed || !identical(_requests[request.movieId], request)) return;
      await _downloadMovie(
          movieId: request.movieId,
          movieTitle: request.title,
          posterPath: request.poster,
          downloadUrl: request.url,
          downloadUrlProvider:
              request.sourceRequest?.resolve ?? request.urlProvider);
    } catch (_) {
      if (identical(_requests[request.movieId], request)) {
        _activeDownloads[
            request
                .movieId] = _activeDownloads[request.movieId]!.copyWith(
            status: DownloadStatus.failed,
            bytesPerSecond: 0,
            errorMessage:
                'Could not save the download queue. Check available storage and retry.');
      }
    } finally {
      if (identical(_requests[request.movieId], request)) {
        _requests.remove(request.movieId);
      }
      if (identical(_running, request)) {
        _running = null;
        _startNext();
      }
      await _checkpoint().catchError((Object _) {});
      if (_running == null) await _background.stop().catchError((Object _) {});
      if (!request.done.isCompleted) request.done.complete();
      _notifyListeners();
    }
  }

  Future<void> _downloadMovie({
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    required String downloadUrl,
    Future<String> Function()? downloadUrlProvider,
  }) async {
    if (_disposed) return;
    if (_downloadAttempts.containsKey(movieId)) return;
    final attempt = ++_nextAttempt;
    _downloadAttempts[movieId] = attempt;
    final queued = _requests[movieId]!;
    http.StreamedResponse? unopenedResponse;

    try {
      if (queued.owner != _owner()) {
        throw StateError('Download account changed.');
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
      await _background.start(movieId, movieTitle);
      if (!_isCurrentAttempt(movieId, attempt)) return;
      if (_activeDownloads[movieId]?.status == DownloadStatus.paused) {
        await _background.stop();
      }

      // Resolve an expired cached link only when this title reaches the front.
      final url =
          (await (downloadUrlProvider?.call() ?? Future.value(downloadUrl)))
              .trim();
      if (!_isCurrentAttempt(movieId, attempt)) return;
      if (url.isEmpty) throw ArgumentError('A download link is required.');

      // App-private storage needs no Android storage permission and remains
      // writable on Android 10+ scoped-storage devices.
      final appDir = await _documentsDirectoryProvider();
      if (!_isCurrentAttempt(movieId, attempt)) return;
      final moviesDir = Directory(p.join(appDir.path, 'movies'));
      if (!await moviesDir.exists()) {
        await moviesDir.create(recursive: true);
      }
      if (!_isCurrentAttempt(movieId, attempt)) return;

      // Start the request before choosing an extension because provider URLs
      // are often tokenized and do not expose one in their path.
      final temporaryFile = File(p.join(moviesDir.path, queued.partialName));
      final offset =
          await temporaryFile.exists() ? await temporaryFile.length() : 0;
      if (!_isCurrentAttempt(movieId, attempt)) return;
      final transfer = await openValidatedDownload(
          client: _client,
          uri: Uri.parse(url),
          offset: offset,
          savedTotalBytes: queued.totalBytes,
          savedETag: queued.etag);
      final response = transfer.response;
      unopenedResponse = response;
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
      final contentLength = transfer.totalBytes;
      int downloadedBytes = transfer.append ? offset : 0;
      int receivedBytes = 0;
      if (!_isCurrentAttempt(movieId, attempt)) {
        await response.stream.listen((_) {}).cancel();
        return;
      }
      final output = await temporaryFile.open(
          mode: transfer.append ? FileMode.append : FileMode.write);
      if (!_isCurrentAttempt(movieId, attempt)) {
        await output.close();
        if (await temporaryFile.exists()) await temporaryFile.delete();
        await response.stream.listen((_) {}).cancel();
        return;
      }
      _openFiles[movieId] = output;
      _temporaryFiles[movieId] = temporaryFile;
      // Clear old bytes before persisting a replacement file's identity.
      // A crash between these operations leaves an empty partial, never old
      // bytes incorrectly labelled with the replacement's ETag.
      if (!transfer.append) await output.flush();
      queued.totalBytes = contentLength;
      queued.etag = transfer.etag;
      queued.downloadedBytes = downloadedBytes;
      try {
        await _checkpoint();
      } catch (_) {
        await response.stream.listen((_) {}).cancel();
        rethrow;
      }
      if (!_isCurrentAttempt(movieId, attempt)) {
        await response.stream.listen((_) {}).cancel();
        return;
      }
      final completion = Completer<void>();
      _downloadCompletions[movieId] = completion;
      final clock = Stopwatch();
      _transferClocks[movieId] = clock;
      if (_activeDownloads[movieId]?.status != DownloadStatus.paused) {
        clock.start();
      }
      _updateProgress(
          movieId, contentLength > 0 ? downloadedBytes / contentLength : 0,
          totalBytes: contentLength, downloadedBytes: downloadedBytes);
      final resumedBytes = downloadedBytes;

      late final StreamSubscription<List<int>> subscription;
      subscription = response.stream
          .timeout(const Duration(seconds: 90))
          .listen(
            (chunk) {
              Future<void> writeChunk() async {
                try {
                  if (!_isCurrentAttempt(movieId, attempt)) return;
                  await output.writeFrom(chunk);
                  downloadedBytes += chunk.length;
                  receivedBytes += chunk.length;
                  queued.downloadedBytes = downloadedBytes;
                  if (_isCurrentAttempt(movieId, attempt)) {
                    final seconds = clock.elapsedMicroseconds /
                        Duration.microsecondsPerSecond;
                    _updateProgress(
                      movieId,
                      contentLength > 0
                          ? (downloadedBytes / contentLength).clamp(0.0, 1.0)
                          : 0,
                      downloadedBytes: downloadedBytes,
                      totalBytes: contentLength,
                      bytesPerSecond: _activeDownloads[movieId]?.status ==
                                  DownloadStatus.paused ||
                              seconds < 0.25
                          ? 0
                          : (downloadedBytes - resumedBytes) / seconds,
                    );
                  }
                } catch (error) {
                  await _failStream(movieId, attempt, error);
                }
              }

              // The stream pauses for each asynchronous disk write. A user pause
              // is an additional pause token and remains in effect afterwards.
              final write = writeChunk();
              _writesInFlight[movieId] = write;
              subscription.pause(write);
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
                receivedBytes: receivedBytes,
                expectedBodyBytes: transfer.expectedBodyBytes,
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
      unopenedResponse = null;
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
          bytesPerSecond: 0,
          downloadedBytes: downloadedBytes,
          totalBytes: downloadedBytes,
        );
        _notifyListeners();
      }
    } catch (error) {
      if (unopenedResponse != null) {
        try {
          await unopenedResponse.stream.listen((_) {}).cancel();
        } catch (_) {}
      }
      if (!_isCurrentAttempt(movieId, attempt)) return;
      _downloadCompletions.remove(movieId);
      await _cleanupDownloadResources(movieId, deleteTemporaryFile: true);
      if (!_isCurrentAttempt(movieId, attempt)) return;
      if (!_disposed && _activeDownloads.containsKey(movieId)) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
          status: DownloadStatus.failed,
          bytesPerSecond: 0,
          errorMessage: error is WambeshaSourceUnavailable
              ? error.message
              : error is WambeshaRequestException
                  ? error.message
                  : error is HttpException
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
        _transferClocks.remove(movieId)?.stop();
        _writesInFlight.remove(movieId);
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
    required int receivedBytes,
    required int? expectedBodyBytes,
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
      if (expectedBodyBytes != null && expectedBodyBytes != receivedBytes) {
        throw const FileSystemException(
            'The response ended before the complete range arrived.');
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
    _transferClocks[movieId]?.stop();
    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.paused,
      bytesPerSecond: 0,
    );
    _notifyListeners();
    await _writesInFlight[movieId];
    try {
      await _openFiles[movieId]?.flush();
    } on FileSystemException {/* Retry can restart safely. */}
    await _checkpoint();
    await _background.stop();
  }

  /// Resume download
  Future<void> resumeDownload(int movieId) async {
    if (_disposed ||
        _activeDownloads[movieId]?.status != DownloadStatus.paused) {
      return;
    }

    if (_recoveryPaused) {
      _recoveryPaused = false;
      _startNext();
      return;
    }
    try {
      await _background.start(movieId, _activeDownloads[movieId]!.movieTitle);
    } catch (_) {
      if (_activeDownloads[movieId]?.status == DownloadStatus.paused) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!
            .copyWith(errorMessage: 'Open the app and try resuming again.');
        _notifyListeners();
      }
      return;
    }
    if (_disposed ||
        _activeDownloads[movieId]?.status != DownloadStatus.paused) {
      return;
    }

    _activeSubscriptions[movieId]?.resume();
    _transferClocks[movieId]?.start();
    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.downloading,
      clearError: true,
    );
    _notifyListeners();
  }

  /// Cancel download
  Future<void> cancelDownload(int movieId) async {
    if (_disposed) return;
    final request = _requests.remove(movieId);
    _downloadAttempts.remove(movieId);
    _transferClocks.remove(movieId)?.stop();
    final completion = _downloadCompletions.remove(movieId);
    await _cleanupDownloadResources(movieId, deleteTemporaryFile: true);
    if (request != null &&
        (request.downloadedBytes > 0 ||
            request.totalBytes > 0 ||
            request.etag != null)) {
      final root = await _documentsDirectoryProvider();
      final partial = File(p.join(root.path, 'movies', request.partialName));
      if (await partial.exists()) await partial.delete();
    }
    _activeDownloads.remove(movieId);
    if (_recoveryPaused && _requests.isNotEmpty) {
      final next = _requests.values.first.movieId;
      _activeDownloads[next] =
          _activeDownloads[next]!.copyWith(status: DownloadStatus.paused);
    }
    if (_requests.isEmpty) _recoveryPaused = false;
    _notifyListeners();
    if (completion != null && !completion.isCompleted) {
      completion.completeError(StateError('Download was cancelled.'));
    }
    if (request != null && identical(_running, request)) _running = null;
    _startNext();
    await _checkpoint();
    if (_running == null) await _background.stop();
    if (request != null && !request.done.isCompleted) request.done.complete();
  }

  /// Update download progress
  void _updateProgress(
    int movieId,
    double progress, {
    int? downloadedBytes,
    int? totalBytes,
    double? bytesPerSecond,
  }) {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      progress: progress,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      bytesPerSecond: bytesPerSecond,
    );
    _notifyListeners();
  }

  /// Notify listeners of changes
  void _notifyListeners() {
    if (!_disposed && !_downloadController.isClosed) {
      _downloadController.add(Map.from(_activeDownloads));
      final now = DateTime.now();
      final running = _activeDownloads[_running?.movieId];
      if (running?.status == DownloadStatus.downloading &&
          now.difference(_lastNotification).inSeconds >= 1) {
        _lastNotification = now;
        unawaited(_background
            .update(running!.movieId, running.movieTitle, running.progress)
            .catchError((Object _) {}));
      }
      if (_requests.isNotEmpty &&
          now.difference(_lastCheckpoint).inSeconds >= 2) {
        _lastCheckpoint = now;
        unawaited(_checkpoint().catchError((Object _) {}));
      }
    }
  }

  /// Get download status for a specific movie
  DownloadStatus? getDownloadStatus(int movieId) {
    return _activeDownloads[movieId]?.status;
  }

  /// Find local file path for a completed download, if it exists on disk.
  Future<String?> getDownloadedFilePath(int movieId) async {
    try {
      final appDir = await _documentsDirectoryProvider();
      for (final folder in ['movies', 'downloads']) {
        final directory = Directory(p.join(appDir.path, folder));
        if (!await directory.exists()) continue;
        await for (final entry in directory.list()) {
          if (entry is File &&
              p.basename(entry.path).startsWith('${movieId}_') &&
              ['.mp4', '.mkv', '.mov', '.webm', '.avi']
                  .contains(p.extension(entry.path).toLowerCase()) &&
              await entry.length() > 0) {
            return entry.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Restore saved status after restarting, and clear it if the file vanished.
  Future<void> refreshDownloadStatus({
    required int movieId,
    required String movieTitle,
    String? posterPath,
  }) async {
    if (_disposed || _requests.containsKey(movieId)) return;
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
      if (_disposed || _requests.containsKey(movieId)) return;
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
    unawaited(_background.stop().catchError((Object _) {}));
    _downloadAttempts.clear();
    for (final request in _requests.values) {
      if (!request.done.isCompleted) request.done.complete();
    }
    _requests.clear();
    _running = null;
    for (final clock in _transferClocks.values) {
      clock.stop();
    }
    _transferClocks.clear();
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

class _QueuedDownload {
  _QueuedDownload(
      this.movieId, this.title, this.poster, this.url, this.urlProvider,
      {this.sourceRequest,
      this.owner,
      this.etag,
      this.totalBytes = 0,
      this.downloadedBytes = 0,
      String? partialName})
      : partialName = partialName ??
            '.download_${movieId}_${DateTime.now().microsecondsSinceEpoch}_${++_fileSequence}.part';
  static int _fileSequence = 0;
  final String partialName;
  final int movieId;
  final String title;
  final String? poster;
  final String url;
  final Future<String> Function()? urlProvider;
  final DownloadSourceRequest? sourceRequest;
  final String? owner;
  String? etag;
  int totalBytes;
  int downloadedBytes;
  final done = Completer<void>();

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'title': title,
        'poster': poster,
        'url': url,
        'sourceRequest': sourceRequest?.toJson(),
        'owner': owner,
        'etag': etag,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'partialName': partialName
      };
  factory _QueuedDownload.fromJson(Map<String, dynamic> json) {
    final id = json['movieId'] as int;
    final name = json['partialName'] as String? ?? '.download_$id.part';
    if (!RegExp('^\\.download_$id(?:_\\d+_\\d+)?\\.part\$').hasMatch(name)) {
      throw const FormatException('Invalid download checkpoint path.');
    }
    return _QueuedDownload(id, json['title'] as String,
        json['poster'] as String?, json['url'] as String, null,
        partialName: name,
        owner: json['owner'] as String?,
        etag: json['etag'] as String?,
        totalBytes: json['totalBytes'] as int,
        downloadedBytes: json['downloadedBytes'] as int,
        sourceRequest: json['sourceRequest'] == null
            ? null
            : DownloadSourceRequest.fromJson(
                Map<String, dynamic>.from(json['sourceRequest'] as Map)));
  }
}
