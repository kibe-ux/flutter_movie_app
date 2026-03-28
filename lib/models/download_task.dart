enum DownloadTaskStatus {
  idle,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.movieId,
    required this.movieTitle,
    required this.movieYear,
    required this.quality,
    required this.savePath,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadTaskStatus.idle,
    this.errorMessage,
  });

  final String id;
  final String movieId;
  final String movieTitle;
  final int movieYear;
  final String quality;
  final String savePath;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final DownloadTaskStatus status;
  final String? errorMessage;

  DownloadTask copyWith({
    String? id,
    String? movieId,
    String? movieTitle,
    int? movieYear,
    String? quality,
    String? savePath,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    DownloadTaskStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      movieYear: movieYear ?? this.movieYear,
      quality: quality ?? this.quality,
      savePath: savePath ?? this.savePath,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
