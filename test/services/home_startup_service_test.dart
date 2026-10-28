import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/home_startup_service.dart';
import 'package:moviehub_app/services/catalogue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  setUp(() {
    dotenv.testLoad(fileInput: 'MOVIE_API_KEY=test');
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
  });
  tearDown(() => messenger.setMockMethodCallHandler(connectivity, null));

  test(
      'initial feed loads four categories and filters future and duplicate movies',
      () async {
    var requests = 0;
    await http.runWithClient(() async {
      final result = await HomeStartupService().load();
      expect(result.connected, isTrue);
      expect(requests, 4);
      expect(result.categories.keys, HomeStartupService.endpoints.keys);
      final movies = result.categories.values.expand((items) => items).toList();
      expect(movies.length, 5);
      expect(movies.where((movie) => movie['id'] == 1), hasLength(1));
      expect(movies.any((movie) => movie['id'] == 999), isFalse);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters['page'], '1');
              expect(request.url.queryParameters['api_key'], 'test');
              return http.Response(
                  jsonEncode({
                    'results': [
                      {'id': 1, 'release_date': '2020-01-01'},
                      {'id': ++requests + 1, 'release_date': '2020-01-01'},
                      {'id': 999, 'release_date': '2999-01-01'},
                    ]
                  }),
                  200);
            }));
  });

  test('offline startup does not wait for movie requests', () async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['none']);
    await http.runWithClient(() async {
      final result = await HomeStartupService().load();
      expect(result.connected, isFalse);
      expect(result.categories, isEmpty);
    },
        () => MockClient(
            (_) async => throw StateError('Unexpected network request')));
  });

  test('failed feed request surfaces an error for splash retry', () async {
    await http.runWithClient(() async {
      await expectLater(
          HomeStartupService().load(), throwsA(isA<CatalogueLoadException>()));
    }, () => MockClient((_) async => http.Response('Unavailable', 503)));
  });

  test('one unavailable category keeps the other startup movies usable',
      () async {
    var id = 0;
    await http.runWithClient(() async {
      final result = await HomeStartupService().load();
      expect(result.categoryErrors.keys, ['Now Playing']);
      expect(result.categories['Trending Today'], isNotEmpty);
      expect(result.categories['Now Playing'], isEmpty);
      expect(result.categories['Popular Movies'], isNotEmpty);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/now_playing')) {
                return http.Response('Unavailable', 503);
              }
              return http.Response(
                  jsonEncode({
                    'results': [
                      {'id': ++id}
                    ]
                  }),
                  200);
            }));
  });
}
