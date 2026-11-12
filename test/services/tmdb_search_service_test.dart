import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/services/tmdb_search_service.dart';

void main() {
  test('TV-only search does not request or wait for movie results', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
        fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=http://127.0.0.1:3000');
    final requests = <Uri>[];
    await http.runWithClient(() async {
      final results =
          await TmdbSearchService().search('TV-only regression', type: 'tv');
      expect(results.single['media_type'], 'tv');
      expect(requests.single.path, '/api/catalogue/3/search/tv');
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                  '{"results":[{"id":42,"name":"TV result"}]}', 200);
            }));
  });
  test('search uses only TMDB proxy and reuses results across instances',
      () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
        fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=http://127.0.0.1:3000');
    final requests = <Uri>[];
    await http.runWithClient(() async {
      final results = await TmdbSearchService().search('Cache regression');
      expect(results.map((row) => row['media_type']), ['movie', 'tv']);
      await TmdbSearchService().search('Cache regression');
      expect(requests, hasLength(2));
      expect(requests.map((uri) => uri.path),
          ['/api/catalogue/3/search/movie', '/api/catalogue/3/search/tv']);
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return http.Response(
                  jsonEncode({
                    'results': [
                      {'id': 123, 'title': 'Result'}
                    ]
                  }),
                  200);
            }));
  });
}
