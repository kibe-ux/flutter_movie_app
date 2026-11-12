import 'package:moviehub_app/services/tmdb_api.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/catalogue_json_client.dart';
import 'package:moviehub_app/services/catalogue_page_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores genres and cards after reopening, while refresh fetches anew',
      () async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    CatalogueJsonClient create(CataloguePageCache cache) => CatalogueJsonClient(
          pageCache: cache,
          client: MockClient((request) async {
            requests++;
            return http.Response(
                request.url.path.contains('/genre/')
                    ? '{"genres":[{"id":28,"name":"Action"}]}'
                    : '{"results":[{"id":1,"title":"Cached movie"}]}',
                200);
          }),
        );
    final genres = TmdbApi.uri('genre/movie/list');
    final cards = TmdbApi.uri('discover/movie');
    final cache = CataloguePageCache(persistenceKey: 'explore_test');
    final first = create(cache);
    await first.get(genres);
    await first.get(cards);
    await cache.flush();
    first.close();
    final reopened = create(CataloguePageCache(persistenceKey: 'explore_test'));
    addTearDown(reopened.close);
    expect((await reopened.get(genres))['genres'], isNotEmpty);
    expect((await reopened.get(cards))['results'], isNotEmpty);
    expect(requests, 2);
    await reopened.get(cards, refresh: true);
    expect(requests, 3);
  });
  final uri = TmdbApi.uri('movie/popular');
  test('reuses successful responses, refreshes explicitly and expires old data',
      () async {
    var now = DateTime(2026);
    var requests = 0;
    final client = CatalogueJsonClient(
        now: () => now,
        client: MockClient(
            (_) async => http.Response('{"version":${++requests}}', 200)));
    addTearDown(client.close);
    expect((await client.get(uri))['version'], 1);
    expect((await client.get(uri))['version'], 1);
    expect((await client.get(uri, refresh: true))['version'], 2);
    now = now.add(const Duration(minutes: 6));
    expect((await client.get(uri))['version'], 3);
    expect(requests, 3);
  });

  test(
      'concurrent requests share a fetch and failed responses remain retryable',
      () async {
    var requests = 0;
    final pending = Completer<http.Response>();
    final client = CatalogueJsonClient(client: MockClient((_) async {
      requests++;
      return requests == 1
          ? pending.future
          : http.Response('{"results":[]}', 200);
    }));
    addTearDown(client.close);
    final first = client.get(uri);
    final second = client.get(uri);
    final checks = Future.wait([
      expectLater(first, throwsStateError),
      expectLater(second, throwsStateError),
    ]);
    pending.complete(http.Response('unavailable', 503));
    await checks;
    expect(requests, 1);
    expect(await client.get(uri), {'results': []});
    expect(requests, 2);
  });

  test('movie and TV queries keep separate cached results', () async {
    var requests = 0;
    final client = CatalogueJsonClient(client: MockClient((request) async {
      requests++;
      return http.Response('{"path":"${request.url.path}"}', 200);
    }));
    addTearDown(client.close);
    final tv = TmdbApi.uri('tv/popular');
    expect((await client.get(uri))['path'], '/api/catalogue/3/movie/popular');
    expect((await client.get(tv))['path'], '/api/catalogue/3/tv/popular');
    await client.get(uri);
    await client.get(tv);
    expect(requests, 2);
  });
}
