import 'package:moviehub_app/models/download_item.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/download_service.dart';
import 'package:moviehub_app/services/download_queue_store.dart';
import 'package:moviehub_app/services/download_background_service.dart';
import 'package:moviehub_app/services/download_source_request.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';

class RecordingBackground extends DownloadBackgroundService {
  RecordingBackground() : super(enabled: false);
  final events = <String>[];
  @override
  Future<void> start(int id, String title) async {
    events.add('start:$id');
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }
}

class InspectingStore extends DownloadQueueStore {
  InspectingStore(this.root) : super(() async => root);
  final Directory root;
  int? replacementPartialLength;
  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    for (final job in snapshot['jobs'] as List) {
      if (job['etag'] == '"new"' && replacementPartialLength == null) {
        replacementPartialLength =
            await File('${root.path}/movies/${job['partialName']}').length();
      }
    }
    await super.save(snapshot);
  }
}

void main() {
  late Directory directory;
  final services = <DownloadService>[];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('queue-recovery-');
  });
  tearDown(() async {
    for (final service in services) {
      service.dispose();
      await service.flushQueue();
    }
    services.clear();
    await directory.delete(recursive: true);
  });
  DownloadQueueStore store() => DownloadQueueStore(() async => directory);
  DownloadService create(http.Client client,
      {String owner = 'user-a', RecordingBackground? background}) {
    final service = DownloadService.forTesting(
        client: client,
        documentsDirectoryProvider: () async => directory,
        queueStore: store(),
        ownerProvider: () => owner,
        backgroundService: background);
    services.add(service);
    return service;
  }

  for (final changed in [false, true]) {
    test(
        'reopening restores queue paused and ${changed ? 'restarts replaced bytes' : 'resumes identical bytes'}',
        () async {
      final body = StreamController<List<int>>();
      final original = create(MockClient.streaming((_, __) async =>
          http.StreamedResponse(body.stream, 200,
              contentLength: 6,
              headers: {'etag': '"old"', 'content-type': 'video/mp4'})));
      final progress = original.downloadsStream
          .firstWhere((items) => items[1]?.downloadedBytes == 3);
      unawaited(original.downloadMovie(
          movieId: 1,
          movieTitle: 'Movie',
          posterPath: null,
          downloadUrl: 'https://delivery.example/file'));
      body.add([1, 2, 3]);
      await progress.timeout(const Duration(seconds: 5));
      unawaited(original.downloadMovie(
          movieId: 2,
          movieTitle: 'Episode',
          posterPath: null,
          downloadUrl: 'https://delivery.example/episode'));
      await original.pauseDownload(1);
      await original.flushQueue();
      original.dispose();
      services.remove(original);
      await body.close();

      var calls = 0;
      final background = RecordingBackground();
      final recovered = create(MockClient.streaming((request, _) async {
        calls++;
        if (request.url.path == '/episode') {
          return http.StreamedResponse(Stream.value([7]), 200,
              contentLength: 1);
        }
        expect(request.headers['range'], 'bytes=3-');
        expect(request.headers['if-range'], '"old"');
        return changed
            ? http.StreamedResponse(Stream.value([9, 8, 7, 6, 5, 4]), 200,
                contentLength: 6,
                headers: {'etag': '"new"', 'content-type': 'video/mp4'})
            : http.StreamedResponse(Stream.value([4, 5, 6]), 206,
                contentLength: 3,
                headers: {
                    'etag': '"old"',
                    'content-range': 'bytes 3-5/6',
                    'content-type': 'video/mp4'
                  });
      }), background: background);
      await recovered.initialize();
      expect(recovered.getDownloadStatus(1), DownloadStatus.paused);
      expect(recovered.getDownloadStatus(2), DownloadStatus.queued);
      expect(calls, 0,
          reason: 'Recovery must not automatically fetch a signed source');
      final completed = recovered.downloadsStream
          .firstWhere((items) => items[2]?.status == DownloadStatus.completed);
      await recovered.resumeDownload(1);
      await completed.timeout(const Duration(seconds: 5));
      final file = await recovered.getDownloadedFilePath(1);
      expect(await File(file!).readAsBytes(),
          changed ? [9, 8, 7, 6, 5, 4] : [1, 2, 3, 4, 5, 6]);
      expect(calls, 2);
      expect(background.events.where((event) => event.startsWith('start')),
          ['start:1', 'start:2']);
      await recovered.flushQueue();
    });
  }

  Map<String, dynamic> job(int id) => {
        'movieId': id,
        'title': 'Title $id',
        'poster': null,
        'url': 'https://delivery.example/$id',
        'owner': 'user-a',
        'etag': '"old"',
        'totalBytes': 6,
        'downloadedBytes': 3
      };

  test('restored links stay scoped to their original account', () async {
    await store().save({
      'owner': 'user-a',
      'jobs': [job(1)]
    });
    final recovered = create(
        MockClient((_) async => throw StateError('No network')),
        owner: 'user-b');
    await recovered.initialize();
    expect(recovered.activeDownloads, isEmpty);
  });

  test(
      'cancelling restored head deletes its partial and promotes next paused title',
      () async {
    await store().save({
      'owner': 'user-a',
      'jobs': [job(1), job(2)]
    });
    final partial = File('${directory.path}/movies/.download_1.part');
    await partial.create(recursive: true);
    await partial.writeAsBytes([1, 2, 3]);
    final recovered =
        create(MockClient((_) async => throw StateError('No network')));
    await recovered.initialize();
    await recovered.cancelDownload(1);
    expect(await partial.exists(), isFalse);
    expect(recovered.getDownloadStatus(2), DownloadStatus.paused);
    await recovered.cancelDownload(2);
    await recovered.downloadMovie(
        movieId: 3,
        movieTitle: 'New movie',
        posterPath: null,
        downloadUrl: 'https://delivery.example/new');
    expect(recovered.getDownloadStatus(3), DownloadStatus.failed,
        reason: 'New queue must not get stuck behind an empty restored queue');
  });

  test('corrupt latest checkpoint falls back to previous complete snapshot',
      () async {
    final saved = store();
    await saved.save({
      'owner': 'user-a',
      'jobs': [job(1)]
    });
    await saved.save({
      'owner': 'user-a',
      'jobs': [job(1), job(2)]
    });
    await File('${directory.path}/download_queue_0.json')
        .writeAsString('{incomplete');
    final result = await store().load();
    expect((result!['jobs'] as List).length, 1);
  });

  test('replacement checkpoint never labels old bytes with a new ETag',
      () async {
    await store().save({
      'owner': 'user-a',
      'jobs': [job(1)]
    });
    final partial = File('${directory.path}/movies/.download_1.part');
    await partial.create(recursive: true);
    await partial.writeAsBytes([1, 2, 3]);
    final inspected = InspectingStore(directory);
    final service = DownloadService.forTesting(
        client: MockClient.streaming((_, __) async => http.StreamedResponse(
            Stream.value([9, 8, 7, 6, 5, 4]), 200,
            contentLength: 6, headers: {'etag': '"new"'})),
        documentsDirectoryProvider: () async => directory,
        queueStore: inspected,
        ownerProvider: () => 'user-a');
    services.add(service);
    await service.initialize();
    final finished = service.downloadsStream
        .firstWhere((items) => items[1]?.status == DownloadStatus.completed);
    await service.resumeDownload(1);
    await finished.timeout(const Duration(seconds: 5));
    await service.flushQueue();
    expect(inspected.replacementPartialLength, 0,
        reason:
            'A crash after the ETag checkpoint must not leave old partial bytes');
  });

  test('source identity round trip reuses valid URL without Firebase/network',
      () async {
    const url = 'https://delivery.example/file';
    final request = DownloadSourceRequest(
        original: WambeshaSources.fromJson({
          'sources': [
            {
              'kind': 'file_holding',
              'url': url,
              'quality': '720p',
              'expires_at': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            }
          ]
        }),
        selectedUrl: url,
        tmdbId: 42,
        season: 1,
        episode: 2);
    final recovered = DownloadSourceRequest.fromJson(request.toJson());
    expect(await recovered.resolve(), url);
    expect(recovered.season, 1);
    expect(recovered.episode, 2);
  });

  test(
      'notification pause and timeout controls stop transfers without advancing queue',
      () async {
    final body = StreamController<List<int>>();
    final background = RecordingBackground();
    final service = create(
        MockClient.streaming((_, __) async => http.StreamedResponse(
            body.stream, 200,
            contentLength: 6, headers: {'etag': '"old"'})),
        background: background);
    final progress = service.downloadsStream
        .firstWhere((items) => items[1]?.downloadedBytes == 3);
    final finished = service.downloadMovie(
        movieId: 1,
        movieTitle: 'Movie',
        posterPath: null,
        downloadUrl: 'https://delivery.example/file');
    body.add([1, 2, 3]);
    await progress.timeout(const Duration(seconds: 5));
    await background.onControl!('pauseAll', null);
    expect(service.getDownloadStatus(1), DownloadStatus.paused);
    expect(background.events.last, 'stop');
    await service.resumeDownload(1);
    await background.onControl!('pause', 1);
    expect(service.getDownloadStatus(1), DownloadStatus.paused);
    await background.onControl!('cancel', 1);
    await finished;
    expect(service.getDownloadStatus(1), isNull);
    await body.close();
  });
}
