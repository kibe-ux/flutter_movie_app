import 'package:moviehub_app/models/download_item.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/download_service.dart';
import 'package:moviehub_app/services/tv_series_service.dart';

void main() {
  late Directory directory;
  DownloadService? service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('movie-download-test-');
  });

  tearDown(() async {
    service?.dispose();
    service = null;
    await directory.delete(recursive: true);
  });

  DownloadService createService(http.Client client) {
    return service = DownloadService.forTesting(
      client: client,
      documentsDirectoryProvider: () async => directory,
    );
  }

  Future<void> download(DownloadService downloader) => downloader.downloadMovie(
      movieId: 42,
      movieTitle: 'Some Movie',
      posterPath: null,
      downloadUrl: 'https://provider.example/file?token=private');

  test(
      'queue serializes transfers, delays URL resolution and skips cancelled items',
      () async {
    final body = StreamController<List<int>>();
    final started = Completer<void>();
    final requests = <String>[];
    var resolutions = 0;
    final downloader = createService(MockClient.streaming((request, _) async {
      requests.add(request.url.path);
      if (requests.length == 1) {
        started.complete();
        return http.StreamedResponse(body.stream, 200, contentLength: 3);
      }
      return http.StreamedResponse(Stream.value([4, 5, 6]), 200,
          contentLength: 3);
    }));
    final first = download(downloader);
    await started.future;
    final second = downloader.downloadMovie(
        movieId: 43,
        movieTitle: 'Next',
        posterPath: null,
        downloadUrl: 'https://provider.example/stale',
        downloadUrlProvider: () async {
          resolutions++;
          return 'https://provider.example/fresh';
        });
    final third = downloader.downloadMovie(
        movieId: 44,
        movieTitle: 'Cancelled',
        posterPath: null,
        downloadUrl: 'https://provider.example/cancelled');
    expect(downloader.getDownloadStatus(43), DownloadStatus.queued);
    expect(downloader.queuePosition(43), 1);
    expect(downloader.queuePosition(44), 2);
    expect(resolutions, 0);
    await downloader.refreshDownloadStatus(movieId: 43, movieTitle: 'Next');
    expect(downloader.getDownloadStatus(43), DownloadStatus.queued);
    await downloader.cancelDownload(44);
    await third;
    expect(requests, ['/file']);
    body.add([1, 2, 3]);
    await body.close();
    await Future.wait([first, second]);
    expect(resolutions, 1);
    expect(requests, ['/file', '/fresh']);
    expect(downloader.getDownloadStatus(43), DownloadStatus.completed);
  });

  test('failure releases queue slot and duplicate taps share one transfer',
      () async {
    var calls = 0;
    final headers = Completer<http.StreamedResponse>();
    final downloader = createService(MockClient.streaming((request, _) async {
      if (++calls == 1) return headers.future;
      return http.StreamedResponse(Stream.value([1]), 200, contentLength: 1);
    }));
    final first = download(downloader);
    final duplicate = download(downloader);
    final second = downloader.downloadMovie(
        movieId: 43,
        movieTitle: 'Next',
        posterPath: null,
        downloadUrl: 'https://provider.example/next');
    headers.complete(http.StreamedResponse(Stream.value([]), 403));
    await Future.wait([first, duplicate, second]);
    expect(calls, 2);
    expect(downloader.getDownloadStatus(42), DownloadStatus.failed);
    expect(downloader.getDownloadStatus(43), DownloadStatus.completed);
  });

  test('paused transfer holds queue and reports bytes with unknown total',
      () async {
    final body = StreamController<List<int>>();
    final downloader = createService(MockClient.streaming((request, _) async =>
        request.url.path == '/file'
            ? http.StreamedResponse(body.stream, 200)
            : http.StreamedResponse(Stream.value([9]), 200, contentLength: 1)));
    final ready = downloader.downloadsStream
        .firstWhere((items) => items[42]?.downloadedBytes == 2);
    final first = download(downloader);
    final second = downloader.downloadMovie(
        movieId: 43,
        movieTitle: 'Next',
        posterPath: null,
        downloadUrl: 'https://provider.example/next');
    body.add([1, 2]);
    await ready.timeout(const Duration(seconds: 5));
    await downloader.pauseDownload(42);
    expect(downloader.activeDownloads[42]!.downloadedBytes, 2);
    expect(downloader.activeDownloads[42]!.totalBytes, 0);
    expect(downloader.activeDownloads[42]!.bytesPerSecond, 0);
    expect(downloader.activeDownloads[42]!.remainingTime, isNull);
    expect(downloader.getDownloadStatus(43), DownloadStatus.queued);
    body.add([3]);
    final closing = body.close();
    await downloader.resumeDownload(42);
    await Future.wait([first, second, closing]);
    expect(downloader.activeDownloads[42]!.downloadedBytes, 3);
    expect(downloader.activeDownloads[42]!.totalBytes, 3);
    expect(downloader.getDownloadStatus(43), DownloadStatus.completed);
  });

  test(
      'episodes are saved separately and restored with season and episode names',
      () async {
    final downloader = createService(MockClient((_) async =>
        http.Response.bytes([1, 2, 3], 200,
            headers: {'content-type': 'video/mp4'})));
    for (final episode in [101, 102]) {
      await downloader.downloadMovie(
          movieId: episodeDownloadId(episode),
          movieTitle: 'Series S01E${episode - 100} - Episode title',
          posterPath: null,
          downloadUrl: 'https://provider.example/$episode');
    }
    final files = await downloader.getDownloadedMovies();
    expect(files, hasLength(2));
    expect(files.map((file) => file.path).toSet(), hasLength(2));
    expect(
        files.map((file) => file.title),
        containsAll([
          'Series S01E1 - Episode title',
          'Series S01E2 - Episode title',
        ]));
    for (final episode in [101, 102]) {
      await downloader.refreshDownloadStatus(
          movieId: episodeDownloadId(episode), movieTitle: 'Series');
      expect(downloader.getDownloadStatus(episodeDownloadId(episode)),
          DownloadStatus.completed);
    }
  });

  test(
      'saves complete bytes, lists the movie, and permits downloading after deletion',
      () async {
    final downloader = createService(MockClient((_) async =>
        http.Response.bytes([1, 2, 3, 4], 200,
            headers: {'content-type': 'video/mp4'})));
    await download(downloader);
    expect(downloader.getDownloadStatus(42), DownloadStatus.completed);
    final movies = await downloader.getDownloadedMovies();
    expect(movies, hasLength(1));
    expect(movies.single.title, 'Some Movie');
    expect(await File(movies.single.path).readAsBytes(), [1, 2, 3, 4]);
    expect(await downloader.deleteDownloadedMovie(movies.single.path), isTrue);
    expect(downloader.getDownloadStatus(42), isNull);
    await download(downloader);
    expect(downloader.getDownloadStatus(42), DownloadStatus.completed);
  });

  for (final mime in [
    'text/html',
    'application/json',
    'application/x-bittorrent',
    'application/vnd.apple.mpegurl'
  ]) {
    test('does not save $mime as a movie', () async {
      final downloader = createService(MockClient((_) async =>
          http.Response('not a movie', 200, headers: {'content-type': mime})));
      await download(downloader);
      expect(downloader.getDownloadStatus(42), DownloadStatus.failed);
      expect(await downloader.getDownloadedMovies(), isEmpty);
    });
  }

  test('an incomplete body is failed and the partial file is removed',
      () async {
    final downloader = createService(MockClient.streaming((_, __) async =>
        http.StreamedResponse(Stream.value([1, 2, 3]), 200,
            contentLength: 100, headers: {'content-type': 'video/mp4'})));
    await download(downloader);
    expect(downloader.getDownloadStatus(42), DownloadStatus.failed);
    expect(await downloader.getDownloadedMovies(), isEmpty);
    expect(
        await directory
            .list(recursive: true)
            .where((entry) => entry is File)
            .toList(),
        isEmpty);
  });

  test('cancelling while waiting for headers never creates a completed file',
      () async {
    final started = Completer<void>();
    final response = Completer<http.StreamedResponse>();
    final downloader = createService(MockClient.streaming((_, __) {
      started.complete();
      return response.future;
    }));
    final transfer = download(downloader);
    await started.future;
    await downloader.cancelDownload(42);
    response.complete(http.StreamedResponse(Stream.value([1, 2, 3]), 200,
        headers: {'content-type': 'video/mp4'}));
    await transfer;
    expect(downloader.getDownloadStatus(42), isNull);
    expect(await downloader.getDownloadedMovies(), isEmpty);
  });

  test('a late cancelled response cannot overwrite a successful retry',
      () async {
    final started = Completer<void>();
    final oldResponse = Completer<http.StreamedResponse>();
    var requests = 0;
    final downloader = createService(MockClient.streaming((_, __) {
      if (++requests == 1) {
        started.complete();
        return oldResponse.future;
      }
      return Future.value(http.StreamedResponse(Stream.value([4, 5, 6]), 200,
          headers: {'content-type': 'video/mp4'}));
    }));
    final oldTransfer = download(downloader);
    await started.future;
    await downloader.cancelDownload(42);
    await download(downloader);
    oldResponse.complete(http.StreamedResponse(Stream.value([1, 2, 3]), 200,
        headers: {'content-type': 'video/mp4'}));
    await oldTransfer;
    expect(downloader.getDownloadStatus(42), DownloadStatus.completed);
    final movies = await downloader.getDownloadedMovies();
    expect(movies, hasLength(1));
    expect(await File(movies.single.path).readAsBytes(), [4, 5, 6]);
  });

  test('restores saved status without networking, but ignores empty files',
      () async {
    final downloader = createService(
        MockClient((_) async => throw StateError('No network allowed')));
    final saved = File('${directory.path}/movies/42_Some_Movie.mp4');
    await saved.create(recursive: true);
    await downloader.refreshDownloadStatus(
        movieId: 42, movieTitle: 'Some Movie');
    expect(downloader.getDownloadStatus(42), isNull);
    await saved.writeAsBytes([1, 2, 3]);
    await downloader.refreshDownloadStatus(
        movieId: 42, movieTitle: 'Some Movie');
    expect(downloader.getDownloadStatus(42), DownloadStatus.completed);
    await saved.delete();
    await downloader.refreshDownloadStatus(
        movieId: 42, movieTitle: 'Some Movie');
    expect(downloader.getDownloadStatus(42), isNull);
  });

  test('lists both current and legacy folders but hides partial files',
      () async {
    final downloader =
        createService(MockClient((_) async => http.Response('', 200)));
    for (final file in [
      'movies/42_Some_Movie.mp4',
      'downloads/Legacy.Movie.2024.1080p.mp4',
      'movies/unfinished.part'
    ]) {
      final saved =
          await File('${directory.path}/$file').create(recursive: true);
      await saved.writeAsBytes([1, 2, 3]);
    }
    final movies = await downloader.getDownloadedMovies();
    expect(movies, hasLength(2));
    expect(movies.map((movie) => movie.title),
        containsAll(['Some Movie', 'Legacy Movie (2024)']));
  });
}
