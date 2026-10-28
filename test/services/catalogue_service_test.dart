import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/catalogue_service.dart';

void main() {
  final uri = Uri.https('example.test', '/movies', {'page': '2'});

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
