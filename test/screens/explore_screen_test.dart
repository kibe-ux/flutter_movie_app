import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/screens/explore_screen.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'MOVIE_API_KEY=test'));

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
      expect(requests.last.path, '/3/discover/movie');
      await tester.tap(find.text('TV Shows'));
      await tester.pumpAndSettle();
      expect(requests.any((uri) => uri.path == '/3/genre/tv/list'), isTrue);
      expect(requests.last.path, '/3/discover/tv');
      expect(requests.last.queryParameters['with_genres'], '35');
      expect(find.text('Search TV shows...'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Law & Order');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/3/search/tv');
      expect(requests.last.queryParameters['query'], 'Law & Order');

      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      expect(requests.where((uri) => uri.path == '/3/discover/movie'), hasLength(1));
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
      expect(requests.last.path, '/3/discover/movie');
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
              if (request.url.path == '/3/discover/movie') {
                return pendingMovie.future;
              }
              return response(request.url);
            }));
  });
}
