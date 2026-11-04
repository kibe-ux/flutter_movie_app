import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/services/tmdb_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
        fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=https://backend.test');
  });

  test(
      'guest requests use the backend and a stable installation ID without a key',
      () async {
    final identities = <String>[];
    final client = MockClient((request) async {
      expect(request.url.host, 'backend.test');
      expect(request.url.path, '/api/catalogue/3/movie/popular');
      expect(request.url.queryParameters, {'page': '2'});
      expect(request.headers.containsKey('Authorization'), isFalse);
      final id = request.headers['X-MovieHub-Installation']!;
      expect(id, matches(RegExp(r'^[a-f0-9]{32}$')));
      identities.add(id);
      return http.Response('{"results":[]}', 200);
    });
    for (var i = 0; i < 2; i++) {
      await TmdbApi.get(TmdbApi.uri('movie/popular', {'page': '2'}),
          client: client, tokenProvider: (_) async => null);
    }
    expect(identities[0], identities[1]);
  });

  test('only Firebase authentication failures retry with a refreshed token',
      () async {
    final refreshes = <bool>[];
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['Authorization'],
          calls == 1 ? 'Bearer old' : 'Bearer new');
      return calls == 1
          ? http.Response('', 401,
              headers: {'x-moviehub-response-source': 'firebase-auth'})
          : http.Response('{"results":[]}', 200);
    });
    final response = await TmdbApi.get(TmdbApi.uri('movie/popular'),
        client: client, tokenProvider: (refresh) async {
      refreshes.add(refresh);
      return refresh ? 'new' : 'old';
    });
    expect(response.statusCode, 200);
    expect(refreshes, [false, true]);
    expect(calls, 2);
  });

  for (final status in [401, 429, 503]) {
    test(
        'provider failures and rate limits do not trigger automatic retries: $status',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', status);
      });
      final response = await TmdbApi.get(TmdbApi.uri('movie/popular'),
          client: client, tokenProvider: (_) async => 'token');
      expect(response.statusCode, status);
      expect(calls, 1);
    });
  }

  test('credentials cannot be sent to direct provider or unrelated endpoints',
      () async {
    final client = MockClient((_) async => fail('Must not send request'));
    for (final uri in [
      Uri.parse('https://api.themoviedb.org/3/movie/popular'),
      Uri.parse('https://backend.test/api/movies'),
      TmdbApi.uri('movie/popular', {'api_key': 'private-key'}),
    ]) {
      await expectLater(
          TmdbApi.get(uri,
              client: client, tokenProvider: (_) async => 'firebase-token'),
          throwsStateError);
    }
  });
}
