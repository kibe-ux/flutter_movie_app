import 'dart:async';

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
  /// TODO: Replace with your friend's API endpoint
  Future<void> downloadMovie({
    required int movieId,
    required String movieTitle,
    required String? posterPath,
    String? downloadUrl, // Your friend's API will provide this
  }) async {
    if (_disposed) return;

    try {
      // Check if download already exists
      if (_activeDownloads.containsKey(movieId) &&
          _activeDownloads[movieId]!.status == DownloadStatus.downloading) {
        return; // Already downloading
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

      // TODO: Call your friend's API to get download link
      // Example: final downloadUrl = await fetchDownloadUrlFromAPI(movieId);

      // TODO: Implement actual download logic with progress tracking
      // Example implementation pattern:
      // final request = http.Request('GET', Uri.parse(downloadUrl));
      // final response = await request.send().timeout(Duration(seconds: 300));
      // final contentLength = response.contentLength ?? 0;
      //
      // if (contentLength == 0) throw Exception('Invalid content length');
      //
      // List<int> bytes = [];
      // response.stream.listen((chunk) {
      //   if (!_disposed) {
      //     bytes.addAll(chunk);
      //     final progress = bytes.length / contentLength;
      //     _updateProgress(movieId, progress);
      //   }
      // }).onDone(() async {
      //   if (!_disposed) {
      //     await saveDownloadedFile(movieId, movieTitle, bytes);
      //     _completeDownload(movieId);
      //   }
      // }).onError((e) {
      //   if (!_disposed) {
      //     _failDownload(movieId, e.toString());
      //   }
      // });

      // Simulate download for now
      await _simulateDownload(movieId);

      if (!_disposed) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
        );
        _notifyListeners();
      }
    } catch (e) {
      if (!_disposed) {
        _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        _notifyListeners();
      }
    }
  }

  /// Pause download
  Future<void> pauseDownload(int movieId) async {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    // TODO: Implement pause logic with your friend's API
    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.paused,
    );
    _notifyListeners();
  }

  /// Resume download
  Future<void> resumeDownload(int movieId) async {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    // TODO: Implement resume logic with your friend's API
    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.downloading,
    );
    _notifyListeners();
  }

  /// Cancel download
  Future<void> cancelDownload(int movieId) async {
    if (_disposed) return;

    // TODO: Implement cancel logic with your friend's API
    _activeDownloads.remove(movieId);
    _notifyListeners();
  }

  /// Simulate download progress (for testing, remove when API is ready)
  Future<void> _simulateDownload(int movieId) async {
    for (int i = 0; i <= 100; i += 10) {
      if (_disposed) return;
      await Future.delayed(const Duration(milliseconds: 500));
      _updateProgress(movieId, i / 100);
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

  /// Mark download as failed
  void _failDownload(int movieId, String error) {
    if (_disposed || !_activeDownloads.containsKey(movieId)) return;

    _activeDownloads[movieId] = _activeDownloads[movieId]!.copyWith(
      status: DownloadStatus.failed,
      errorMessage: error,
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

  /// Check if movie is downloaded
  bool isDownloaded(int movieId) {
    return _activeDownloads[movieId]?.status == DownloadStatus.completed;
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
