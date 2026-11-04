import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:moviehub_app/services/catalogue_service.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/screens/full_category_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(CatalogueService.resetCacheForTesting);
  setUp(() => dotenv.testLoad(
      fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=http://127.0.0.1:3000'));

  Widget app({int initialPage = 1, String title = 'Popular Movies'}) =>
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: FullCategoryScreen(
          title: title,
          initialPage: initialPage,
          items: const [
            {'id': 1, 'title': 'Already loaded'}
          ],
        ),
      );

  final tvRoutes = {
    'Airing Today': ('/api/catalogue/3/tv/airing_today', null),
    'On the Air': ('/api/catalogue/3/tv/on_the_air', null),
    'Action & Adventure TV': ('/api/catalogue/3/discover/tv', '10759'),
    'Comedy TV': ('/api/catalogue/3/discover/tv', '35'),
    'Crime TV': ('/api/catalogue/3/discover/tv', '80'),
    'Drama TV': ('/api/catalogue/3/discover/tv', '18'),
    'Animation TV': ('/api/catalogue/3/discover/tv', '16'),
    'Documentary TV': ('/api/catalogue/3/discover/tv', '99'),
  };

  for (final entry in tvRoutes.entries) {
    testWidgets('${entry.key} paginates using its TV endpoint and genre',
        (tester) async {
      final requests = <Uri>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(app(title: entry.key, initialPage: 3));
        await tester.tap(find.text('Load More'));
        await tester.pump();
        await tester.pump();
        expect(requests, hasLength(1));
        expect(requests.single.path, entry.value.$1);
        expect(requests.single.queryParameters['with_genres'], entry.value.$2);
        expect(requests.single.queryParameters['page'], '4');
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request.url);
                return http.Response('{"results":[],"total_pages":4}', 200);
              }));
    });
  }

  testWidgets(
      'a failed page retries the same page and preserves existing movies',
      (tester) async {
    final requested = <String?>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app(initialPage: 3));
      await tester.tap(find.text('Load More'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Already loaded'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(requested, ['4', '4']);
      expect(find.text('New movie'), findsOneWidget);
      expect(find.text('Already loaded'), findsOneWidget);
      expect(find.text('Load More'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requested.add(request.url.queryParameters['page']);
              if (requested.length == 1) {
                return http.Response('Unavailable', 503);
              }
              return http.Response(
                  jsonEncode({
                    'results': [
                      {'id': 1},
                      {'id': 2, 'title': 'New movie'}
                    ],
                    'total_pages': 4,
                  }),
                  200);
            }));
  });

  testWidgets(
      'a response after leaving the page does not update disposed state',
      (tester) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('Load More'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      response.complete(http.Response('{"results":[]}', 200));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => response.future));
  });
}
