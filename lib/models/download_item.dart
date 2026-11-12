/// Download status enum
enum DownloadStatus { idle, queued, downloading, paused, completed, failed }

/// Download item model
class DownloadItem {
  final int movieId;
  final String movieTitle;
  final String? posterPath;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage;
  final int downloadedBytes;
  final int totalBytes;
  final double bytesPerSecond;

  Duration? get remainingTime =>
      totalBytes > downloadedBytes && bytesPerSecond > 0
          ? Duration(
              seconds: ((totalBytes - downloadedBytes) / bytesPerSecond).ceil())
          : null;

  DownloadItem({
    required this.movieId,
    required this.movieTitle,
    this.posterPath,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.errorMessage,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
  });

  DownloadItem copyWith({
    int? movieId,
    String? movieTitle,
    String? posterPath,
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
    bool clearError = false,
    int? downloadedBytes,
    int? totalBytes,
    double? bytesPerSecond,
  }) {
    return DownloadItem(
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      posterPath: posterPath ?? this.posterPath,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    );
  }
}
