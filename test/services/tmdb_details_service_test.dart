import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/tmdb_details_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TmdbDetailsService.resetCacheForTesting();
    dotenv.testLoad(
        fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=https://backend.test');
  });

  test('rich details use only the metadata proxy and preserve display fields',
      () async {
    var calls = 0;
    final service = TmdbDetailsService(client: MockClient((request) async {
      calls++;
      expect(request.url.host, 'backend.test');
      expect(request.url.path, '/api/catalogue/3/movie/42');
      expect(request.url.queryParameters.containsKey('api_key'), isFalse);
      expect(request.url.queryParameters['append_to_response'],
          contains('credits,videos'));
      return http.Response(
          jsonEncode({
            'runtime': 116,
            'overview': 'A visitor arrives.',
            'vote_average': 8.1,
            'genres': [
              {'name': 'Science Fiction'}
            ],
            'external_ids': {'imdb_id': 'tt123'},
            'credits': {
              'cast': [
                {'name': 'Actor', 'character': 'Visitor'}
              ]
            },
            'videos': {
              'results': [
                {'key': 'trailer', 'site': 'YouTube', 'type': 'Trailer'}
              ]
            },
          }),
          200);
    }));
    addTearDown(service.dispose);
    final data = await service.fetchDetails(tmdbId: 42, mediaType: 'movie');
    expect(data?['runtime'], 116);
    expect(data?['synopsis'], 'A visitor arrives.');
    expect(data?['imdbId'], 'tt123');
    expect(data?['genres'], ['Science Fiction']);
    expect((data?['casts'] as List).single['name'], 'Actor');
    expect(
        ((data?['videos'] as Map)['results'] as List).single['key'], 'trailer');
    await service.fetchDetails(tmdbId: 42, mediaType: 'movie');
    expect(calls, 1);
    await service.fetchDetails(tmdbId: 42, mediaType: 'movie', refresh: true);
    expect(calls, 2);
  });

  test('details coalesce across services and survive cache recreation',
      () async {
    TmdbDetailsService.resetCacheForTesting(persist: true);
    var calls = 0;
    Future<http.Response> respond(http.Request request) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response(
          jsonEncode({'runtime': 90, 'overview': 'Cached'}), 200);
    }

    final first = TmdbDetailsService(client: MockClient(respond));
    final second = TmdbDetailsService(client: MockClient(respond));
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final results = await Future.wait([
      first.fetchDetails(tmdbId: 99, mediaType: 'movie'),
      second.fetchDetails(tmdbId: 99, mediaType: 'movie'),
    ]);
    expect(calls, 1);
    expect(results.first?['runtime'], 90);
    TmdbDetailsService.resetCacheForTesting(persist: true);
    expect(
        (await second.fetchDetails(tmdbId: 99, mediaType: 'movie'))?['runtime'],
        90);
    expect(calls, 1);
    await second.fetchDetails(tmdbId: 99, mediaType: 'tv');
    expect(calls, 2);
  });

  test('metadata failures never fall back to a source provider', () async {
    for (final status in [404, 503]) {
      var calls = 0;
      final service = TmdbDetailsService(client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/catalogue/3/tv/42');
        return http.Response('{}', status);
      }));
      addTearDown(service.dispose);
      expect(await service.fetchDetails(tmdbId: 42, mediaType: 'tv'), isNull);
      expect(calls, 1);
    }
  });
}
