import '../models/download_item.dart';

String downloadBytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String downloadProgressText(DownloadItem item) {
  final size = item.totalBytes > 0
      ? '${downloadBytes(item.downloadedBytes)} / ${downloadBytes(item.totalBytes)}'
      : '${downloadBytes(item.downloadedBytes)} downloaded';
  if (item.status == DownloadStatus.queued) {
    return 'Waiting for current download';
  }
  if (item.status == DownloadStatus.paused) {
    return 'Paused · $size${item.errorMessage == null ? '' : ' · ${item.errorMessage}'}';
  }
  if (item.status == DownloadStatus.failed) {
    return item.errorMessage ?? 'Download failed';
  }
  if (item.status == DownloadStatus.completed) return size;
  if (item.bytesPerSecond <= 0) return '$size · Calculating speed…';
  final remaining = item.remainingTime;
  final seconds = remaining?.inSeconds;
  final time = seconds == null
      ? ''
      : seconds < 60
          ? ' · ${seconds}s left'
          : seconds < 3600
              ? ' · ${(seconds / 60).ceil()} min left'
              : ' · ${seconds ~/ 3600}h ${seconds % 3600 ~/ 60}m left';
  return '$size · ${downloadBytes(item.bytesPerSecond)}/s$time';
}
