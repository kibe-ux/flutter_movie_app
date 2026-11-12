import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/models/download_item.dart';
import 'package:moviehub_app/utils/download_progress.dart';

void main() {
  test('progress includes size, speed, ETA and handles unknown size', () {
    final item = DownloadItem(
        movieId: 1,
        movieTitle: 'Movie',
        downloadedBytes: 1024,
        totalBytes: 4096,
        bytesPerSecond: 1024,
        status: DownloadStatus.downloading);
    expect(downloadProgressText(item), '1.0 KB / 4.0 KB · 1.0 KB/s · 3s left');
    expect(downloadProgressText(item.copyWith(totalBytes: 0)),
        '1.0 KB downloaded · 1.0 KB/s');
    expect(
        downloadProgressText(
            item.copyWith(status: DownloadStatus.paused, bytesPerSecond: 0)),
        'Paused · 1.0 KB / 4.0 KB');
  });
}
