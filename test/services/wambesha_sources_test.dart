import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';
import 'package:moviehub_app/services/movie_download_service.dart';

Map<String, dynamic> source(String kind, String path, {bool expired = false}) =>
    {
      'kind': kind,
      'url': 'https://delivery.example/$path?sig=private',
      'expires_at': DateTime.now()
          .add(Duration(minutes: expired ? -1 : 60))
          .toIso8601String(),
    };

void main() {
  test('metadata survives parsing and expired auxiliary links prevent reuse',
      () {
    final expiry =
        DateTime.now().add(const Duration(minutes: 2)).toIso8601String();
    final result = WambeshaSources.fromJson({
      'sources': [
        {...source('file_holding', 'movie'), 'bytes': 12345, 'locale': 'en'}
      ],
      'subtitles': [
        {
          'url': 'https://files.example/sub.vtt',
          'language': 'en',
          'format': 'vtt',
          'expires_at': expiry
        }
      ],
      'trailers': [
        {'hosted': 'youtube', 'url': 'https://www.youtube.com/watch?v=test'}
      ],
      'verification_spent': true,
    });
    expect(result.downloadQualities.single['bytes'], '12345');
    expect(result.downloadQualities.single['locale'], 'en');
    expect(result.availableSubtitles.single['language'], 'en');
    expect(result.availableTrailers.single['hosted'], 'youtube');
    expect(result.verificationSpent, isTrue);
    expect(result.isReusable, isTrue);
    result.subtitles.single['expires_at'] = '2000-01-01T00:00:00Z';
    expect(result.availableSubtitles, isEmpty);
    expect(result.isReusable, isFalse);
    expect(WambeshaSources.fromJson({'sources': []}).subtitles, isEmpty);
  });
  test('sources accept external references and cache repeated requests',
      () async {
    var calls = 0;
    final api = WambeshaApiService(
      baseUrlProvider: () => 'https://backend.example',
      tokenProvider: (_) async => 'firebase-token',
      client: MockClient((request) async {
        calls++;
        expect(request.url.pathSegments.last, 'sources');
        return http.Response('{"sources":[]}', 200);
      }),
    );
    addTearDown(api.dispose);
    for (final ref in [
      'imdb:tt0133093',
      'tvdb:123',
      'tmdb:movie:603',
      'tmdb:tv:1399',
      'sn_123'
    ]) {
      await api.sources(ref);
      await api.sources(ref);
    }
    expect(calls, 5);
    for (final ref in [
      'tmdb:123',
      'tmdb:series:123',
      'imdb:123',
      'tvdb:-1',
      'tmdb:movie:1/extra',
      'imdb:tt1?url=other',
      'https://evil.example'
    ]) {
      await expectLater(api.sources(ref), throwsArgumentError);
    }
    expect(calls, 5);
  });
  WambeshaApiService service(http.Client client,
          {Future<String?> Function(bool)? token}) =>
      WambeshaApiService(
        client: client,
        baseUrlProvider: () => 'https://backend.example',
        tokenProvider: token ?? (_) async => 'firebase-token',
      );

  test(
      'movie download and playback select distinct kinds and share one verification',
      () async {
    final requests = <http.Request>[];
    final api = service(MockClient((r) async {
      requests.add(r);
      expect(r.headers['authorization'], 'Bearer firebase-token');
      expect(r.url.queryParameters.containsKey('quality'), isFalse);
      return http.Response(
          jsonEncode({
            'id': 'mv_TEST',
            'sources': [
              source('playback_holding', 'play.mp4'),
              source('file_holding', 'download.mp4'),
            ]
          }),
          200);
    }));
    final downloads = MovieDownloadService.forTesting(sourceService: api);
    expect(
        await downloads.requestSignedDownloadUrl(
            movieId: 'mv_TEST', quality: '1080p'),
        contains('/download.mp4'));
    expect(await downloads.requestPlaybackUrl(movieId: 'mv_TEST'),
        contains('/play.mp4'));
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/wambesha/titles/mv_TEST/sources');
    api.dispose();
  });

  test(
      'concurrent taps share a source request and cache is scoped to user token',
      () async {
    var calls = 0;
    var token = 'user-one';
    final response = Completer<http.Response>();
    final api = service(MockClient((r) async {
      calls++;
      return response.future;
    }), token: (_) async => token);
    final first = api.sources('mv_TEST');
    final second = api.sources('mv_TEST');
    await Future<void>.delayed(Duration.zero);
    response.complete(
        http.Response('{"id":"mv_TEST","sources":[],"unverified":1}', 200));
    final results = await Future.wait([first, second]);
    expect(calls, 1);
    expect(identical(results[0], results[1]), isTrue);
    await api.sources('mv_TEST');
    expect(calls, 1);
    token = 'user-two';
    await api.sources('mv_TEST');
    expect(calls, 2);
    api.dispose();
  });

  test('TMDB lookup resolves identity without sending a numeric ID to sources',
      () async {
    final paths = <String>[];
    final api = service(MockClient((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/lookup')) {
        expect(r.url.queryParameters['tmdb_id'], '329865');
        return http.Response('{"id":"mv_TEST","type":"movie"}', 200);
      }
      return http.Response(
          jsonEncode({
            'id': 'mv_TEST',
            'sources': [source('file_holding', 'movie.mp4')]
          }),
          200);
    }));
    final downloads = MovieDownloadService.forTesting(sourceService: api);
    expect(
        await downloads.requestSignedDownloadUrl(
            movieId: '329865', quality: ''),
        contains('movie.mp4'));
    expect(paths,
        ['/api/wambesha/lookup', '/api/wambesha/titles/mv_TEST/sources']);
    api.dispose();
  });

  test(
      'episode resolution paginates and matches both season and episode before metering',
      () async {
    final paths = <String>[];
    final api = service(MockClient((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/episodes')) {
        expect(r.url.queryParameters['season'], '2');
        if (!r.url.queryParameters.containsKey('cursor')) {
          return http.Response(
              '{"items":[{"id":"ep_WRONG","season_number":1,"episode_number":1}],"next_cursor":"next"}',
              200);
        }
        return http.Response(
            '{"items":[{"id":"ep_RIGHT","season_number":2,"episode_number":1}],"next_cursor":null}',
            200);
      }
      expect(r.url.path, '/api/wambesha/titles/ep_RIGHT/sources');
      return http.Response(
          jsonEncode({
            'id': 'ep_RIGHT',
            'sources': [source('file_holding', 'episode.mp4')]
          }),
          200);
    }));
    final result = await api.episodeSources(
        seriesTmdbId: 1, seriesRef: 'sr_TEST', season: 2, episode: 1);
    expect(result.requireUrl('file_holding'), contains('episode.mp4'));
    expect(paths.where((p) => p.endsWith('/sources')), hasLength(1));
    api.dispose();
  });

  test(
      'warming identity shares lookup with download without checking files early',
      () async {
    final lookup = Completer<http.Response>();
    final paths = <String>[];
    final api = service(MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/lookup')) return lookup.future;
      return http.Response(
          jsonEncode({
            'sources': [source('file_holding', 'movie.mp4')],
          }),
          200);
    }));
    final warmup = api.resolveTitle(tmdbId: 550, type: 'movie');
    await Future<void>.delayed(Duration.zero);
    expect(paths, ['/api/wambesha/lookup']);
    final download = api.movieSources(tmdbId: 550);
    lookup.complete(http.Response('{"id":"mv_TEST","type":"movie"}', 200));
    expect(await warmup, 'mv_TEST');
    expect((await download).hasDownload, isTrue);
    await api.movieSources(tmdbId: 550);
    expect(paths,
        ['/api/wambesha/lookup', '/api/wambesha/titles/mv_TEST/sources']);
    api.dispose();
  });

  test('identity cache stays scoped to the current user and media type',
      () async {
    var user = 'first-user';
    var lookups = 0;
    final api = service(MockClient((request) async {
      lookups++;
      return http.Response(
          jsonEncode({
            'id': lookups == 3 ? 'sr_TEST' : 'mv_TEST',
            'type': lookups == 3 ? 'series' : 'movie',
          }),
          200);
    }), token: (_) async => user);
    expect(await api.resolveTitle(tmdbId: 550, type: 'movie'), 'mv_TEST');
    expect(await api.resolveTitle(tmdbId: 550, type: 'movie'), 'mv_TEST');
    expect(lookups, 1);
    user = 'second-user';
    await api.resolveTitle(tmdbId: 550, type: 'movie');
    expect(lookups, 2);
    expect(await api.resolveTitle(tmdbId: 550, type: 'tv'), 'sr_TEST');
    expect(lookups, 3);
    api.dispose();
  });

  test('failed identity warmup is not cached and download can retry', () async {
    var calls = 0;
    final api = service(MockClient((request) async {
      calls++;
      return calls == 1
          ? http.Response('{}', 502)
          : http.Response('{"id":"mv_TEST","type":"movie"}', 200);
    }));
    await expectLater(api.resolveTitle(tmdbId: 550, type: 'movie'),
        throwsA(isA<WambeshaRequestException>()));
    expect(await api.resolveTitle(tmdbId: 550, type: 'movie'), 'mv_TEST');
    expect(calls, 2);
    api.dispose();
  });

  test('delivery links without optional expiry can be downloaded and reused',
      () async {
    var calls = 0;
    const url = 'https://delivery.wambesha.com/v1/download/test-file';
    final api = service(MockClient((_) async {
      calls++;
      return http.Response(
          jsonEncode({
            'id': 'mv_GCZQF6WP7B',
            'sources': [
              {
                'kind': 'file_holding',
                'url': url,
                'host': 'Wambesha Delivery Network'
              }
            ]
          }),
          200);
    }));
    final downloads = MovieDownloadService.forTesting(sourceService: api);
    for (var i = 0; i < 2; i++) {
      expect(
          await downloads.requestSignedDownloadUrl(
              movieId: 'mv_GCZQF6WP7B', quality: ''),
          url);
    }
    expect(calls, 1);
    api.dispose();
  });

  test('no source, expired links and torrent entries cannot become downloads',
      () {
    for (final sources in [
      <Map<String, dynamic>>[],
      [source('file_holding', 'expired.mp4', expired: true)],
      [
        {...source('file_holding', 'bad-expiry.mp4'), 'expires_at': 'invalid'}
      ],
      [
        {...source('file_holding', 'bad-expiry-type.mp4'), 'expires_at': 123}
      ],
      [
        {'kind': 'file_holding', 'url': 'http://delivery.example/file'}
      ],
      [source('torrent_listing', 'not-a-file')],
      [source('playback_holding', 'play.mp4')]
    ]) {
      final result = WambeshaSources(sources: sources, unverified: 1);
      expect(() => result.requireUrl('file_holding'),
          throwsA(isA<WambeshaSourceUnavailable>()));
    }
  });

  test('expired cache refreshes and explicit retries do not reuse client cache',
      () async {
    var calls = 0;
    final api = service(MockClient((_) async {
      calls++;
      return http.Response(
          jsonEncode({
            'id': 'mv_TEST',
            'sources': [source('file_holding', 'file.mp4', expired: calls == 1)]
          }),
          200);
    }));
    await api.sources('mv_TEST');
    (await api.sources('mv_TEST')).requireUrl('file_holding');
    expect(calls, 2);
    await api.sources('mv_TEST', refresh: true);
    expect(calls, 3);
    api.dispose();
  });

  test('ambiguous identifiers fail without spending a source verification',
      () async {
    var calls = 0;
    final api = service(MockClient((_) async {
      calls++;
      return http.Response('{}', 409);
    }));
    await expectLater(
        api.movieSources(tmdbId: 1), throwsA(isA<WambeshaRequestException>()));
    expect(calls, 1);
    api.dispose();
  });

  test('stream-only sources never appear as downloadable quality options', () {
    final sources = WambeshaSources(
        sources: [source('playback_holding', 'playlist.m3u8')], unverified: 0);
    expect(sources.downloadQualities, isEmpty);
    expect(sources.urlForQuality('720p'), isNull);
  });
}
