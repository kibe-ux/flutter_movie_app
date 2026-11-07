import 'package:moviehub_app/services/tmdb_api.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/catalogue_service.dart';

void main() {
  setUp(CatalogueService.resetCacheForTesting);
  final uri = TmdbApi.uri('discover/movie', {'page': '2'});

  test('default service instances reuse a shared catalogue page', () async {
    var calls = 0;
    await http.runWithClient(() async {
      await const CatalogueService().fetchPage(uri);
      await const CatalogueService().fetchPage(uri);
      expect(calls, 1);
      await const CatalogueService().fetchPage(uri, refresh: true);
      expect(calls, 2);
    },
        () => MockClient((_) async {
              calls++;
              return http.Response('{"results":[]}', 200);
            }));
  });

  test('filters invalid and future items and recognizes the final page',
      () async {
    await http.runWithClient(() async {
      final page = await const CatalogueService().fetchPage(uri);
      expect(page.items.map((item) => item['id']), [1]);
      expect(page.hasMore, isFalse);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'results': [
                {'id': 1},
                {'id': 2, 'release_date': '2999-01-01'},
                {'title': 'Missing identifier'},
              ],
              'total_pages': 2,
            }),
            200)));
  });

  test(
      'Wambesha pages retain an opaque next cursor even when no records can display',
      () async {
    await http.runWithClient(() async {
      final page = await const CatalogueService().fetchPage(uri);
      expect(page.items, isEmpty);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque_next');
    },
        () => MockClient((_) async => http.Response(
            '{"results":[],"catalogue_provider":"wambesha","has_more":true,"next_cursor":"opaque_next"}',
            200)));
  });

  test('empty results stop pagination without total_pages metadata', () async {
    await http.runWithClient(() async {
      expect((await const CatalogueService().fetchPage(uri)).hasMore, isFalse);
    }, () => MockClient((_) async => http.Response('{"results":[]}', 200)));
  });

  for (final body in ['not JSON', '{"unexpected":[]}']) {
    test('malformed catalogue data surfaces a readable retry error: $body',
        () async {
      await http.runWithClient(() async {
        await expectLater(
            const CatalogueService().fetchPage(uri),
            throwsA(isA<CatalogueLoadException>().having(
                (error) => error.message,
                'message',
                contains('read the movie list'))));
      }, () => MockClient((_) async => http.Response(body, 200)));
    });
  }

  test('HTTP failures do not expose response bodies or request parameters',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          const CatalogueService().fetchPage(uri),
          throwsA(isA<CatalogueLoadException>().having(
              (error) => error.message,
              'message',
              'Movies are temporarily unavailable. Please try again.')));
    },
        () => MockClient(
            (_) async => http.Response('internal provider failure', 503)));
  });

  test('slow requests time out with a useful retry message', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await expectLater(
          const CatalogueService(timeout: Duration(milliseconds: 10))
              .fetchPage(uri),
          throwsA(isA<CatalogueLoadException>().having(
              (error) => error.message, 'message', contains('took too long'))));
      response.complete(http.Response('{"results":[]}', 200));
    }, () => MockClient((_) => response.future));
  });
}
