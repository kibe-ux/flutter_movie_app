import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/download_service.dart';

// Diagnostic tests only: no provider, credentials, or production logic changes.
void main() {
  late Directory directory;
  DownloadService? service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('repeat-download-check-');
  });

  tearDown(() async {
    service?.dispose();
    service = null;
    await directory.delete(recursive: true);
  });

  Future<void> download({String url = 'https://files.example/movie.mp4'}) =>
      service!.downloadMovie(
          movieId: 42,
          movieTitle: 'Same Movie',
          posterPath: null,
          downloadUrl: url);

  test('completed movie downloads again without deleting its file or state',
      () async {
    var requests = 0;
    service = DownloadService.forTesting(
      client: MockClient((_) async => http.Response.bytes([++requests], 200,
          headers: {'content-type': 'video/mp4'})),
      documentsDirectoryProvider: () async => directory,
    );
    await download();
    expect(service!.getDownloadStatus(42), DownloadStatus.completed);
    expect(service!.activeDownloads.containsKey(42), isTrue);
    final original = (await service!.getDownloadedMovies()).single;
    await service!.refreshDownloadStatus(movieId: 42, movieTitle: 'Same Movie');
    await download();
    expect(requests, 2,
        reason: 'A completed attempt must not retain its dedup lock.');
    expect(service!.getDownloadStatus(42), DownloadStatus.completed);
    final replacement = (await service!.getDownloadedMovies()).single;
    expect(replacement.path, original.path);
    expect(await File(replacement.path).readAsBytes(), [2]);
    expect(service!.activeDownloads[42]!.errorMessage, isNull);
    print(
        'DIAGNOSTIC completed-repeat requests=2 first=completed second=completed keptFile=true');
  });

  test('failed HTTP attempt releases the lock for the same movie', () async {
    var requests = 0;
    service = DownloadService.forTesting(
      client: MockClient((_) async => ++requests == 1
          ? http.Response('origin unavailable', 500)
          : http.Response.bytes([2], 200,
              headers: {'content-type': 'video/mp4'})),
      documentsDirectoryProvider: () async => directory,
    );
    await download();
    expect(service!.getDownloadStatus(42), DownloadStatus.failed);
    await download();
    expect(requests, 2);
    expect(service!.getDownloadStatus(42), DownloadStatus.completed);
    print('DIAGNOSTIC failure-repeat requests=2 first=failed second=completed');
  });

  test('only a still-running attempt makes a duplicate call a silent no-op',
      () async {
    var requests = 0;
    final started = Completer<void>();
    final headers = Completer<http.StreamedResponse>();
    service = DownloadService.forTesting(
      client: MockClient.streaming((_, __) {
        requests++;
        if (requests == 1) {
          started.complete();
          return headers.future;
        }
        return Future.value(http.StreamedResponse(Stream.value([2]), 200,
            contentLength: 1, headers: {'content-type': 'video/mp4'}));
      }),
      documentsDirectoryProvider: () async => directory,
    );
    final first = download();
    await started.future;
    await download();
    expect(requests, 1);
    expect(service!.getDownloadStatus(42), DownloadStatus.downloading);
    expect(service!.activeDownloads[42]!.errorMessage, isNull);
    headers.complete(http.StreamedResponse(Stream.value([1]), 200,
        contentLength: 1, headers: {'content-type': 'video/mp4'}));
    await first;
    await download();
    expect(requests, 2);
    expect(service!.getDownloadStatus(42), DownloadStatus.completed);
    print(
        'DIAGNOSTIC in-flight-duplicate requestsWhileActive=1 error=null afterCompletionRequests=2');
  });

  test('invalid URL early failure releases the attempt lock', () async {
    var requests = 0;
    service = DownloadService.forTesting(
      client: MockClient((_) async => http.Response.bytes([++requests], 200,
          headers: {'content-type': 'video/mp4'})),
      documentsDirectoryProvider: () async => directory,
    );
    await download(url: '');
    expect(requests, 0);
    await download();
    expect(requests, 1);
    expect(service!.getDownloadStatus(42), DownloadStatus.completed);
    print(
        'DIAGNOSTIC invalid-url-repeat networkCallsAfterFailure=0 afterRetry=1 status=completed');
  });
}
