import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/screens/search_screen.dart';
import 'package:moviehub_app/services/cache_service.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'MOVIE_API_KEY=test');
    SharedPreferences.setMockInitialValues({});
    CacheService.clearMemCache();
  });

  Widget app() => MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const SearchScreen(),
      );

  http.Response genres() => http.Response(
      '{"genres":[{"id":35,"name":"Comedy"},{"id":18,"name":"Drama"}]}', 200);

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  testWidgets('exact TV matches rank above partial movies; tabs limit requests',
      (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await search(tester, 'Orbit');
      expect(find.text('2 results · Best matches first'), findsOneWidget);
      final exactTitle = find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Orbit');
      expect(tester.getTopLeft(exactTitle).dy,
          lessThan(tester.getTopLeft(find.text('Orbit Returns')).dy));
      requests.clear();
      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.path, '/3/search/movie');
      expect(exactTitle, findsNothing);
      expect(find.text('1 result · Best matches first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/genre/')) return genres();
              requests.add(request.url);
              final movie = request.url.path.endsWith('/movie');
              return http.Response(
                  jsonEncode({
                    'results': [
                      {
                        'id': 42,
                        if (movie)
                          'title': 'Orbit Returns'
                        else
                          'name': 'Orbit',
                        'popularity': movie ? 100 : 1,
                      }
                    ]
                  }),
                  200);
            }));
  });

  testWidgets('genre filters returned titles and can be removed from a chip',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movies'));
      await search(tester, 'Night');
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comedy').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Night Laughs'), findsOneWidget);
      expect(find.text('Night Drama'), findsNothing);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Night Drama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/genre/')) return genres();
              return http.Response(
                  '{"results":[{"id":1,"title":"Night Laughs","genre_ids":[35]},'
                  '{"id":2,"title":"Night Drama","genre_ids":[18]}]}',
                  200);
            }));
  });

  testWidgets('HTTP errors show retry rather than an empty results message',
      (tester) async {
    var fail = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await search(tester, 'Orbit');
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text("No results for 'Orbit'"), findsNothing);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsNothing);
      expect(find.text("No results for 'Orbit'"), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/genre/')) return genres();
              return http.Response(
                  fail ? 'Unavailable' : '{"results":[]}', fail ? 503 : 200);
            }));
  });

  testWidgets('typing invalidates old responses before the debounce expires',
      (tester) async {
    final old = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Old');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.enterText(find.byType(TextField), 'New');
      old.complete(
          http.Response('{"results":[{"id":1,"title":"Old result"}]}', 200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Old result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text("No results for 'New'"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.contains('/genre/')) return genres();
              if (request.url.queryParameters['query'] == 'Old') {
                return old.future;
              }
              return http.Response('{"results":[]}', 200);
            }));
  });
}
