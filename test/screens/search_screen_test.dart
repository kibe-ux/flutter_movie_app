import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/screens/search_screen.dart';
import 'package:moviehub_app/services/cache_service.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';

class FakeSearch extends WambeshaApiService {
  Future<List<Map<String, dynamic>>> Function(String) handler = (_) async => [];
  final queries = <String>[];
  @override
  Future<List<Map<String, dynamic>>> genres() async => [
        {'id': 1, 'name': 'Comedy'},
        {'id': 2, 'name': 'Drama'},
      ];
  @override
  Future<List<Map<String, dynamic>>> search(String query) {
    queries.add(query);
    return handler(query);
  }
}

void main() {
  late FakeSearch service;
  setUp(() {
    dotenv.testLoad(fileInput: 'MOVIE_API_KEY=test');
    SharedPreferences.setMockInitialValues({});
    CacheService.clearMemCache();
    service = FakeSearch();
  });
  tearDown(() => service.dispose());
  Widget app() => MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: SearchScreen(searchService: service),
      );
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  testWidgets('Wambesha movies and TV results rank and filter by type',
      (tester) async {
    service.handler = (_) async => [
          {'id': 42, 'title': 'Orbit Returns', 'media_type': 'movie'},
          {'id': 43, 'name': 'Orbit', 'media_type': 'tv'},
        ];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await search(tester, 'Orbit');
    final exact = find.byWidgetPredicate((w) => w is Text && w.data == 'Orbit');
    expect(tester.getTopLeft(exact).dy,
        lessThan(tester.getTopLeft(find.text('Orbit Returns')).dy));
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(exact, findsNothing);
    expect(find.text('Orbit Returns'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genre and year filters use Wambesha metadata', (tester) async {
    service.handler = (_) async => [
          {
            'id': 1,
            'title': 'Night Laughs',
            'media_type': 'movie',
            'genre_ids': [1],
            'year': 2020
          },
          {
            'id': 2,
            'title': 'Night Drama',
            'media_type': 'movie',
            'genre_ids': [2],
            'year': 2020
          },
        ];
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await search(tester, 'Night');
    expect(find.text('2020'), findsNWidgets(2));
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
  });

  testWidgets('quota errors show retry rather than no results', (tester) async {
    service.handler = (_) async => throw const WambeshaRequestException(429);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await search(tester, 'Orbit');
    expect(find.text('Source check limit reached. Please try again later.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    service.handler = (_) async => [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("No results for 'Orbit'"), findsOneWidget);
  });

  testWidgets('typing invalidates old responses before debounce expires',
      (tester) async {
    final old = Completer<List<Map<String, dynamic>>>();
    service.handler = (q) => q == 'Old' ? old.future : Future.value([]);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Old');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.enterText(find.byType(TextField), 'New');
    old.complete([
      {'id': 1, 'title': 'Old result', 'media_type': 'movie'}
    ]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Old result'), findsNothing);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text("No results for 'New'"), findsOneWidget);
  });

  testWidgets('one character does not send a search request', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await search(tester, 'a');
    expect(service.queries, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
