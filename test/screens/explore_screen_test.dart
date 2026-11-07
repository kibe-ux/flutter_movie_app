import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/screens/explore_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(() => dotenv.testLoad(
      fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=http://127.0.0.1:3000'));

  Widget app() => MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const ExploreScreen(myListIds: <int>{}),
      );

  http.Response response(Uri uri) => http.Response(
        jsonEncode(uri.path.contains('/genre/')
            ? {
                'genres': [
                  {'id': 35, 'name': 'Comedy'}
                ]
              }
            : {'results': []}),
        200,
      );

  testWidgets('switching tabs loads TV genres and searches the selected type',
      (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/catalogue/3/discover/movie');
      await tester.tap(find.text('TV Shows'));
      await tester.pumpAndSettle();
      expect(
          requests.any((uri) => uri.path == '/api/catalogue/3/genre/tv/list'),
          isTrue);
      expect(requests.last.path, '/api/catalogue/3/discover/tv');
      expect(requests.last.queryParameters['with_genres'], '35');
      expect(find.text('Search TV shows...'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Law & Order');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/catalogue/3/search/tv');
      expect(requests.last.queryParameters['query'], 'Law & Order');

      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(
          requests
              .where((uri) => uri.path == '/api/catalogue/3/discover/movie'),
          hasLength(1));
      expect(find.text('Search movies...'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return response(request.url);
            }));
  });

  testWidgets('Sci-Fi & Adventure requests both movie genres', (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sci-Fi & Adventure'));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/catalogue/3/discover/movie');
      expect(requests.last.queryParameters['with_genres'], '878,12');
      await tester.tap(find.text('TV Shows'));
      await tester.pumpAndSettle();
      expect(find.text('Sci-Fi & Adventure'), findsNothing);
    },
        () => MockClient((request) async {
              requests.add(request.url);
              return response(request.url);
            }));
  });

  testWidgets(
      'returning to Movies restores posters immediately without requests',
      (tester) async {
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Saved movie result'), findsOneWidget);
      await tester.tap(find.text('TV Shows'));
      await tester.pumpAndSettle();
      expect(find.text('Saved TV result'), findsOneWidget);
      final loadedRequests = requests.length;
      await tester.tap(find.text('Movies'));
      await tester.pump();
      expect(find.text('Saved movie result'), findsOneWidget);
      expect(find.text('Saved TV result'), findsNothing);
      expect(requests.length, loadedRequests);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              requests.add(request.url);
              if (request.url.path.contains('/genre/')) {
                return response(request.url);
              }
              final tv = request.url.path.endsWith('/tv');
              return http.Response(
                  jsonEncode({
                    'results': [
                      {
                        'id': tv ? 2 : 1,
                        tv ? 'name' : 'title':
                            tv ? 'Saved TV result' : 'Saved movie result'
                      }
                    ]
                  }),
                  200);
            }));
  });

  testWidgets(
      'each tab retains its search and a late inactive response cannot replace it',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Movie search');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TV Shows'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Slow TV search');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      final loadedRequests = requests;
      await tester.tap(find.text('Movies'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Movie search');
      expect(find.text('Movie search result'), findsOneWidget);
      pending.complete(http.Response(
          '{"results":[{"id":99,"name":"Late TV result"}]}', 200));
      await tester.pumpAndSettle();
      expect(find.text('Late TV result'), findsNothing);
      expect(find.text('Movie search result'), findsOneWidget);
      expect(requests, loadedRequests);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              requests++;
              if (request.url.path.endsWith('/search/tv')) {
                return pending.future;
              }
              if (request.url.path.endsWith('/search/movie')) {
                return http.Response(
                    '{"results":[{"id":1,"title":"Movie search result"}]}',
                    200);
              }
              return response(request.url);
            }));
  });

  testWidgets('a late movie response cannot overwrite the TV tab',
      (tester) async {
    final pendingMovie = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('TV Shows'));
      await tester.pumpAndSettle();
      expect(find.text('No TV shows found for this genre/search.'),
          findsOneWidget);
      pendingMovie.complete(
          http.Response('{"results":[{"id":123,"title":"Stale movie"}]}', 200));
      await tester.pumpAndSettle();
      expect(find.text('Stale movie'), findsNothing);
      expect(find.text('No TV shows found for this genre/search.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/api/catalogue/3/discover/movie') {
                return pendingMovie.future;
              }
              return response(request.url);
            }));
  });
}
