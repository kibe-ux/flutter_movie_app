import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/services/metadata_list_service.dart';
import 'package:moviehub_app/services/tv_series_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetadataListService.resetCacheForTesting(persist: true);
    dotenv.testLoad(fileInput:
        'MOVIE_DOWNLOAD_API_BASE_URL=https://metadata.test');
  });

  test('TV lists share pending calls, persist, and keep seasons separate', () async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      final a = TvSeriesService();
      final b = TvSeriesService();
      final seasons = await Future.wait([a.seasons(42), b.seasons(42)]);
      expect(requests, hasLength(1));
      seasons.first.first['name'] = 'Changed locally';
      expect(seasons.last.first['name'], 'Season');
      await a.episodes(42, 1);
      await b.episodes(42, 2);
      expect(requests, hasLength(3));
      MetadataListService.resetCacheForTesting(persist: true);
      await b.seasons(42);
      await b.episodes(42, 1);
      expect(requests, hasLength(3));
      expect(requests.every((uri) => uri.host == 'metadata.test' &&
          uri.path.startsWith('/api/catalogue/3/tv/')), isTrue);
    }, () => MockClient((request) async {
      requests.add(request.url);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return http.Response(jsonEncode({
        request.url.path.contains('/season/') ? 'episodes' : 'seasons': [
          {'id': 1, 'name': 'Season'}
        ]
      }), 200);
    }));
  });

  test('similar titles cache successfully but failures remain retryable', () async {
    var calls = 0;
    await http.runWithClient(() async {
      final service = MetadataListService();
      await expectLater(service.fetch('movie/42/similar'), throwsStateError);
      await expectLater(service.fetch('movie/42/similar'), throwsFormatException);
      final result = await service.fetch('movie/42/similar');
      expect(result.single['id'], 123);
      await MetadataListService().fetch('movie/42/similar');
      expect(calls, 3);
    }, () => MockClient((request) async {
      calls++;
      if (calls == 1) return http.Response('{}', 503);
      if (calls == 2) return http.Response('{}', 200);
      return http.Response('{"results":[{"id":123}]}', 200);
    }));
  });
}
