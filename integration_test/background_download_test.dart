import 'package:moviehub_app/models/download_item.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moviehub_app/services/download_service.dart';
import 'package:moviehub_app/services/download_background_service.dart';
import 'package:moviehub_app/services/download_queue_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android foreground download finishes after its activity closes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Background download check'))));
    final root = await (await getTemporaryDirectory())
        .createTemp('background-download-check-');
    final body = StreamController<List<int>>();
    final background = DownloadBackgroundService();
    final service = DownloadService.forTesting(
        client: MockClient.streaming((_, __) async => http.StreamedResponse(
            body.stream, 200,
            contentLength: 6,
            headers: {'etag': '"test-file"', 'content-type': 'video/mp4'})),
        documentsDirectoryProvider: () async => root,
        queueStore: DownloadQueueStore(() async => root),
        backgroundService: background);
    try {
      final progress = service.downloadsStream
          .firstWhere((items) => items[900001]?.downloadedBytes == 3);
      final finished = service.downloadMovie(
          movieId: 900001,
          movieTitle: 'Background download check',
          posterPath: null,
          downloadUrl: 'https://test.invalid/fixture.mp4');
      body.add([1, 2, 3]);
      await progress.timeout(const Duration(seconds: 30));
      // Android detaches the Activity; the service must retain the Dart engine.
      await SystemNavigator.pop();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
          WidgetsBinding.instance.lifecycleState, AppLifecycleState.detached);
      body.add([4, 5, 6]);
      await body.close();
      await finished.timeout(const Duration(seconds: 15));
      expect(service.getDownloadStatus(900001), DownloadStatus.completed);
      expect(
          await File((await service.getDownloadedFilePath(900001))!)
              .readAsBytes(),
          [1, 2, 3, 4, 5, 6]);
      await background.stop();
    } finally {
      service.dispose();
      await service.flushQueue();
      await body.close();
      await root.delete(recursive: true);
    }
  });
}
