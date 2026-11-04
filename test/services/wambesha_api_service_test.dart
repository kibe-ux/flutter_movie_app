import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';

void main() {
  test(
      'search batches title records, preserves relevance and maps TMDB identity',
      () async {
    final requests = <http.Request>[];
    final service = WambeshaApiService(
      baseUrlProvider: () => 'https://backend.example',
      tokenProvider: (_) async => 'firebase-token',
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['authorization'], 'Bearer firebase-token');
        if (request.url.path.endsWith('/search')) {
          expect(request.url.queryParameters['q'], 'Arrival & more');
          return http.Response(
              jsonEncode({
                'titles': {
                  'items': [
                    {'id': 'mv_A', 'type': 'movie'},
                    {'id': 'sr_B', 'type': 'series'},
                    {'id': 'mv_C', 'type': 'movie'},
                  ]
                }
              }),
              200);
        }
        expect(request.url.queryParameters['ids'], 'mv_A,sr_B,mv_C');
        return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'sr_B',
                  'type': 'series',
                  'title': 'B',
                  'external_ids': {'tmdb_id': '2'}
                },
                {'id': 'mv_C', 'type': 'movie', 'external_ids': {}},
                {
                  'id': 'mv_A',
                  'type': 'movie',
                  'title': 'A',
                  'year': 2016,
                  'external_ids': {'tmdb_id': '329865'},
                  'poster': {'url': 'https://art.example/poster.webp'},
                  'genres': [
                    {'id': 7, 'name': 'Drama'}
                  ]
                },
              ],
              'missing': []
            }),
            200);
      }),
    );
    final items = await service.search(' Arrival & more ');
    expect(requests.map((r) => r.url.path),
        ['/api/wambesha/search', '/api/wambesha/titles']);
    expect(items.map((i) => i['id']), [329865, 2]);
    expect(items.first['wambesha_id'], 'mv_A');
    expect(items.first['genre_ids'], [7]);
    expect(items.first['poster_url'], 'https://art.example/poster.webp');
    expect(items.last['media_type'], 'tv');
    expect(items.last['name'], 'B');
  });

  test(
      'one-character queries and empty search results never fetch batch titles',
      () async {
    var calls = 0;
    final service = WambeshaApiService(
      baseUrlProvider: () => 'https://backend.example',
      tokenProvider: (_) async => 'token',
      client: MockClient((_) async {
        calls++;
        return http.Response('{"titles":{"items":[]}}', 200);
      }),
    );
    expect(await service.search('a'), isEmpty);
    expect(calls, 0);
    expect(await service.search('Unknown'), isEmpty);
    expect(calls, 1);
  });

  test('only Firebase 401 refreshes the token, and only once', () async {
    final refreshes = <bool>[];
    var requests = 0;
    final service = WambeshaApiService(
      baseUrlProvider: () => 'https://backend.example',
      tokenProvider: (refresh) async {
        refreshes.add(refresh);
        return refresh ? 'new' : 'old';
      },
      client: MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response('{}', 401,
              headers: {'x-moviehub-response-source': 'firebase-auth'});
        }
        expect(request.headers['authorization'], 'Bearer new');
        return http.Response('{"items":[]}', 200);
      }),
    );
    expect(await service.genres(), isEmpty);
    expect(refreshes, [false, true]);
    expect(requests, 2);
  });

  test('provider failures and quota errors are surfaced without retrying',
      () async {
    for (final status in [401, 429, 502]) {
      var calls = 0;
      final service = WambeshaApiService(
        baseUrlProvider: () => 'https://backend.example',
        tokenProvider: (_) async => 'token',
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', status,
              headers: {'x-moviehub-response-source': 'wambesha'});
        }),
      );
      await expectLater(
          service.genres(),
          throwsA(isA<WambeshaRequestException>()
              .having((e) => e.statusCode, 'status', status)));
      expect(calls, 1);
    }
  });
}
