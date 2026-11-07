import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';

void main() {
  late List<Uri> requests;
  WambeshaApiService service(List<Map<String, dynamic>> records,
      {int lookupStatus = 404}) {
    requests = [];
    return WambeshaApiService(
      baseUrlProvider: () => 'https://backend.example',
      tokenProvider: (_) async => 'test-token',
      client: MockClient((request) async {
        requests.add(request.url);
        final path = request.url.path;
        if (path.endsWith('/lookup')) return http.Response('{}', lookupStatus);
        if (path.endsWith('/search')) {
          expect(request.url.queryParameters['q'], 'The Thing');
          expect(request.url.queryParameters.containsKey('type'), isFalse);
          return http.Response(
              jsonEncode({
                'titles': {'items': records}
              }),
              200);
        }
        if (path.endsWith('/titles')) {
          return http.Response(jsonEncode({'items': records}), 200);
        }
        if (path.endsWith('/episodes')) {
          return http.Response(
              '{"items":[{"id":"ep_RIGHT","season_number":2,"episode_number":3}]}',
              200);
        }
        return http.Response(
            '{"sources":[{"kind":"file_holding","url":"https://files.example/movie.mp4"}]}',
            200);
      }),
    );
  }

  Map<String, dynamic> record(String id,
          {int year = 1982,
          int? tmdb,
          String title = 'The Thing',
          String type = 'movie'}) =>
      {
        'id': id,
        'type': type,
        'title': title,
        'year': year,
        'external_ids': {if (tmdb != null) 'tmdb_id': tmdb},
      };

  test(
      'movie fallback finds unique title and year without a provider TMDB link',
      () async {
    final api = service([record('mv_REMAKE', year: 2011), record('mv_RIGHT')]);
    addTearDown(api.dispose);
    final sources = await api.movieSources(
        tmdbId: 1091, title: 'The Thing', releaseDate: '1982-06-25');
    expect(sources.hasDownload, isTrue);
    expect(requests.last.path, '/api/wambesha/titles/mv_RIGHT/sources');
    await api.movieSources(
        tmdbId: 1091, title: 'The Thing', releaseDate: '1982-06-25');
    expect(requests, hasLength(4));
  });

  test('exact external identity takes priority over an unlinked title match',
      () async {
    final api =
        service([record('mv_UNLINKED'), record('mv_RIGHT', tmdb: 1091)]);
    addTearDown(api.dispose);
    expect(
        await api.resolveTitle(
            tmdbId: 1091,
            type: 'movie',
            title: 'The Thing',
            releaseDate: '1982-06-25'),
        'mv_RIGHT');
  });

  for (final candidate in [
    {'label': 'another TMDB identity', 'record': record('mv_WRONG', tmdb: 999)},
    {'label': 'a remake', 'record': record('mv_WRONG', year: 2011)},
    {
      'label': 'a different title',
      'record': record('mv_WRONG', title: 'Something Else')
    },
    {'label': 'a TV show', 'record': record('sr_WRONG', type: 'series')},
  ]) {
    test('fallback rejects ${candidate['label']} before requesting sources',
        () async {
      final api = service([candidate['record'] as Map<String, dynamic>]);
      addTearDown(api.dispose);
      await expectLater(
          api.movieSources(
              tmdbId: 1091, title: 'The Thing', releaseDate: '1982-06-25'),
          throwsA(isA<WambeshaSourceUnavailable>()));
      expect(requests.any((uri) => uri.path.endsWith('/sources')), isFalse);
    });
  }

  test('duplicate title and year matches remain ambiguous', () async {
    final api = service([record('mv_ONE'), record('mv_TWO')]);
    addTearDown(api.dispose);
    await expectLater(
        api.movieSources(
            tmdbId: 1091, title: 'The Thing', releaseDate: '1982-06-25'),
        throwsA(isA<WambeshaSourceUnavailable>()
            .having((e) => e.message, 'message', contains('More than one'))));
    expect(requests.any((uri) => uri.path.endsWith('/sources')), isFalse);
  });

  test('unknown release year cannot guess an unlinked movie', () async {
    final api = service([record('mv_RIGHT')]);
    addTearDown(api.dispose);
    await expectLater(api.movieSources(tmdbId: 1091, title: 'The Thing'),
        throwsA(isA<WambeshaSourceUnavailable>()));
  });

  for (final status in [401, 409, 429, 502]) {
    test('HTTP $status does not trigger extra search or source requests',
        () async {
      final api = service([], lookupStatus: status);
      addTearDown(api.dispose);
      await expectLater(
          api.movieSources(
              tmdbId: 1091, title: 'The Thing', releaseDate: '1982-06-25'),
          throwsA(isA<WambeshaRequestException>()
              .having((e) => e.statusCode, 'status', status)));
      expect(requests, hasLength(1));
    });
  }

  test(
      'episode fallback resolves the series before matching season and episode',
      () async {
    final api = service([record('sr_RIGHT', type: 'series')]);
    addTearDown(api.dispose);
    final sources = await api.episodeSources(
        seriesTmdbId: 123,
        seriesTitle: 'The Thing',
        releaseDate: '1982-06-25',
        season: 2,
        episode: 3);
    expect(sources.hasDownload, isTrue);
    expect(requests[3].path, '/api/wambesha/titles/sr_RIGHT/episodes');
    expect(requests.last.path, '/api/wambesha/titles/ep_RIGHT/sources');
  });
}
