import 'package:moviehub_app/services/tmdb_api.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/services/catalogue_page_cache.dart';
import 'package:moviehub_app/services/catalogue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late CataloguePageCache cache;
  final uri = TmdbApi.uri('discover/movie', {
    'page': '1',
    'language': 'en-US',
  });
  String body(int id) => jsonEncode({
        'results': [
          {'id': id, 'title': 'Movie $id'}
        ],
        'total_pages': 3,
      });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 11, 4, 12);
    cache = CataloguePageCache(now: () => now);
  });

  test('screens share requests, return independent data, and refresh on demand',
      () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final first = CatalogueService(cache: cache).fetchPage(uri);
      final second = CatalogueService(cache: cache).fetchPage(uri);
      // Let the persistent cache initialize before completing the request.
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      pending.complete(http.Response(body(1), 200));
      final results = await Future.wait([first, second]);
      expect(results.every((page) => page.items.single['id'] == 1), isTrue);
      results.first.items.single['title'] = 'Changed by a screen';
      expect(
          (await CatalogueService(cache: cache).fetchPage(uri))
              .items
              .single['title'],
          'Movie 1');
      expect(calls, 1);
      await CatalogueService(cache: cache).fetchPage(uri, refresh: true);
      expect(calls, 2);
    },
        () => MockClient((_) {
              calls++;
              return calls == 1
                  ? pending.future
                  : Future.value(http.Response(body(2), 200));
            }));
  });

  test(
      'saved pages survive a new cache instance but retain their original expiry',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      await CatalogueService(cache: cache).fetchPage(uri);
      now = now.add(const Duration(minutes: 10));
      final restarted =
          CatalogueService(cache: CataloguePageCache(now: () => now));
      expect((await restarted.fetchPage(uri)).items.single['id'], 1);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 5));
      expect((await restarted.fetchPage(uri)).items.single['id'], 2);
      expect(calls, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CataloguePageCache.storageKey),
          isNot(contains(uri.toString())));
    }, () => MockClient((_) async => http.Response(body(++calls), 200)));
  });

  test('page, language and filters have separate cache entries',
      () async {
    var calls = 0;
    final requests = [
      uri,
      uri.replace(queryParameters: {...uri.queryParameters, 'page': '2'}),
      uri.replace(queryParameters: {...uri.queryParameters, 'language': 'sw'}),
      uri.replace(
          queryParameters: {...uri.queryParameters, 'with_genres': '35'}),
          ];
    await http.runWithClient(() async {
      for (final request in requests) {
        await CatalogueService(cache: cache).fetchPage(request);
      }
      final reordered = uri.replace(queryParameters: {
        for (final key in uri.queryParameters.keys.toList().reversed)
          key: uri.queryParameters[key]!,
      });
      await CatalogueService(cache: cache).fetchPage(reordered);
      expect(calls, requests.length);
    }, () => MockClient((_) async => http.Response(body(++calls), 200)));
  });

  for (final failure in [
    http.Response('failure', 503),
    http.Response('{"wrong":[]}', 200)
  ]) {
    test(
        'failed responses are shared, retried, and never saved: ${failure.statusCode} ${failure.body}',
        () async {
      var calls = 0;
      await http.runWithClient(() async {
        final service = CatalogueService(cache: cache);
        await expectLater(
            Future.wait([service.fetchPage(uri), service.fetchPage(uri)]),
            throwsA(isA<CatalogueLoadException>()));
        expect(calls, 1);
        expect((await service.fetchPage(uri)).items.single['id'], 2);
        expect(calls, 2);
      },
          () => MockClient((_) async =>
              ++calls == 1 ? failure : http.Response(body(2), 200)));
    });
  }

  test('a failed refresh keeps the last valid cached page', () async {
    var calls = 0;
    await http.runWithClient(() async {
      final service = CatalogueService(cache: cache);
      await service.fetchPage(uri);
      await expectLater(service.fetchPage(uri, refresh: true),
          throwsA(isA<CatalogueLoadException>()));
      expect((await service.fetchPage(uri)).items.single['id'], 1);
      expect(calls, 2);
    },
        () => MockClient((_) async => ++calls == 1
            ? http.Response(body(1), 200)
            : http.Response('', 503)));
  });

  test('entry limits evict older pages on disk as well as in memory', () async {
    var calls = 0;
    cache = CataloguePageCache(now: () => now, maxEntries: 2);
    await http.runWithClient(() async {
      final service = CatalogueService(cache: cache);
      for (var page = 1; page <= 3; page++) {
        await service.fetchPage(uri.replace(
            queryParameters: {...uri.queryParameters, 'page': '$page'}));
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
          (jsonDecode(prefs.getString(CataloguePageCache.storageKey)!) as Map)
              .length,
          2);
      await CatalogueService(
              cache: CataloguePageCache(now: () => now, maxEntries: 2))
          .fetchPage(uri);
      expect(calls, 4);
    }, () => MockClient((_) async => http.Response(body(++calls), 200)));
  });

  test('oversized responses are returned without persisting them', () async {
    var calls = 0;
    cache = CataloguePageCache(now: () => now, maxBytes: 1);
    await http.runWithClient(() async {
      final service = CatalogueService(cache: cache);
      await service.fetchPage(uri);
      await service.fetchPage(uri);
      expect(calls, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(
          jsonDecode(prefs.getString(CataloguePageCache.storageKey)!), isEmpty);
    }, () => MockClient((_) async => http.Response(body(++calls), 200)));
  });

  test('corrupt disk data does not prevent browsing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CataloguePageCache.storageKey, 'not JSON');
    await http.runWithClient(() async {
      expect(
          (await CatalogueService(cache: cache).fetchPage(uri))
              .items
              .single['id'],
          1);
    }, () => MockClient((_) async => http.Response(body(1), 200)));
  });

  test('concurrent pages both survive persistent cache writes', () async {
    var calls = 0;
    final nextPage = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'page': '2',
    });
    await http.runWithClient(() async {
      final service = CatalogueService(cache: cache);
      await Future.wait([service.fetchPage(uri), service.fetchPage(nextPage)]);
      final restarted =
          CatalogueService(cache: CataloguePageCache(now: () => now));
      await restarted.fetchPage(uri);
      await restarted.fetchPage(nextPage);
      expect(calls, 2);
    }, () => MockClient((_) async => http.Response(body(++calls), 200)));
  });
}
