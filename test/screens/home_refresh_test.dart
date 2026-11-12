import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:moviehub_app/services/catalogue_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/screens/home_screen.dart';
import 'package:moviehub_app/services/home_startup_service.dart';
import 'package:moviehub_app/widgets/home_movie_carousel.dart';

void main() {
  testWidgets('first movie row appears while slower initial rows are pending',
      (tester) async {
    final slow = Completer<http.Response>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (_) async => ['wifi']);
    await http.runWithClient(() async {
      await tester
          .pumpWidget(const MaterialApp(home: HomeScreen(myListIds: {})));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(slow.isCompleted, isFalse);
      expect(find.byType(HomeMovieCarousel), findsOneWidget);
      expect(
          tester
              .widget<HomeMovieCarousel>(find.byType(HomeMovieCarousel))
              .movies
              .first['id'],
          101);
      await tester.pumpWidget(const SizedBox());
      slow.complete(http.Response('{"results":[]}', 200));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/trending/movie/day')) {
                return http.Response(
                    '{"results":[{"id":101,"title":"Fast first row"}]}', 200);
              }
              return slow.future;
            }));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(CatalogueService.resetCacheForTesting);
  setUp(() {
    dotenv.testLoad(
        fileInput: 'MOVIE_DOWNLOAD_API_BASE_URL=http://127.0.0.1:3000');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    messenger.setMockMessageHandler('plugins.flutter.io/google_mobile_ads',
        (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null));
  });

  Future<void> openHome(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(
      myListIds: {},
      initialData: HomeStartupData(connected: true, categories: {
        'Now Playing': [
          {'id': 1, 'title': 'Original poster'}
        ],
      }),
    )));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  http.Response response(List<Map<String, dynamic>> items) =>
      http.Response(jsonEncode({'results': items, 'total_pages': 8}), 200);

  testWidgets(
      'Home removes the catalogue text and repeats no cards between rows',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          home: HomeScreen(
        myListIds: {},
        initialData: HomeStartupData(connected: true, categories: {
          'Trending Today': [
            {'id': 1, 'title': 'Shared movie'}
          ],
          'Top Rated': [
            {'id': 1, 'title': 'Shared movie'},
            {'id': 2, 'title': 'Top rated exclusive'}
          ],
        }),
      )));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Wambesha catalogue'), findsNothing);
      final topRated =
          find.byKey(const PageStorageKey('home-posters-Top Rated'));
      await tester.scrollUntilVisible(topRated, 200,
          scrollable: find
              .descendant(
                  of: find.byKey(
                      const PageStorageKey('home-categories-All Movies')),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.descendant(of: topRated, matching: find.text('Shared movie')),
          findsNothing);
      expect(
          find.descendant(
              of: topRated, matching: find.text('Top rated exclusive')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => response([])));
  });

  testWidgets('duplicate-heavy seeded rows refill through bounded cursor pages',
      (tester) async {
    final ratingRequests = <Uri>[];
    final repeated = [
      for (var id = 1; id <= 6; id++) {'id': id, 'title': 'Shared $id'}
    ];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: HomeScreen(
        myListIds: const {},
        initialData: HomeStartupData(connected: true, categories: {
          'Trending Today': repeated,
          'Top Rated': repeated,
        }, hasMore: const {
          'Trending Today': false,
          'Top Rated': true
        }, nextCursors: const {
          'Top Rated': 'cursor1'
        }),
      )));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
          ratingRequests.map((uri) => uri.queryParameters['page']), ['2', '3']);
      expect(ratingRequests.map((uri) => uri.queryParameters['cursor']),
          [null, null]);
      final row = find.byKey(const PageStorageKey('home-posters-Top Rated'));
      await tester.scrollUntilVisible(row, 200,
          scrollable: find
              .descendant(
                  of: find.byKey(
                      const PageStorageKey('home-categories-All Movies')),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.descendant(of: row, matching: find.text('Distinct movie')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Shared 1')),
          findsNothing);
      expect(ratingRequests, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/movie/top_rated')) {
                return response([]);
              }
              ratingRequests.add(request.url);
              final page = request.url.queryParameters['page'];
              return http.Response(
                  jsonEncode({
                    'results': page == '2'
                        ? repeated
                        : [
                            {'id': 7, 'title': 'Distinct movie'}
                          ],
                    'total_pages': 20,
                    'has_more': true,
                    'next_cursor': page == '2' ? 'cursor2' : 'cursor3',
                  }),
                  200);
            }));
  });

  testWidgets(
      'TV filter loads TV rows only and returning restores movie posters',
      (tester) async {
    final paths = <Uri>[];
    var id = 100;
    await http.runWithClient(() async {
      await openHome(tester);
      paths.clear();
      await tester.tap(find.text('TV Shows'));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(paths, isNotEmpty);
      expect(
          paths.every((uri) => (uri.path.startsWith('/api/catalogue/3/tv/') ||
              uri.path.startsWith('/api/catalogue/3/trending/tv/') ||
              uri.path == '/api/catalogue/3/discover/tv')),
          isTrue);
      expect(find.text('Now Playing'), findsNothing);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics && widget.properties.label == 'TV poster'),
          findsWidgets);
      await tester.tap(find.text('All Movies'));
      await tester.pump();
      expect(find.text('Original poster'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              paths.add(request.url);
              final tv = request.url.path.contains('/tv/') ||
                  request.url.path.endsWith('/tv');
              return response([
                {
                  'id': id++,
                  tv ? 'name' : 'title': tv ? 'TV poster' : 'Movie poster',
                  'media_type': tv ? 'tv' : 'movie'
                }
              ]);
            }));
  });

  testWidgets('refresh keeps extra pages, row position and pagination progress',
      (tester) async {
    final requestedPages = <String>[];
    var refreshing = false;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await openHome(tester);
      expect(find.text('Load More'), findsNothing);
      final row = find.byKey(const PageStorageKey('home-posters-Now Playing'));
      await tester.drag(row, const Offset(-300, 0));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.text('Extra page poster'), findsWidgets);
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: row, matching: find.byType(Scrollable)).first);
      scroll.position.jumpTo(10);
      await tester.pump();
      final offset = scroll.position.pixels;
      refreshing = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.text('Original poster'), findsOneWidget);
      expect(find.text('Extra page poster'), findsWidgets);
      pending.complete(response([
        {'id': 1, 'title': 'Updated poster'},
        {'id': 3, 'title': 'New poster'}
      ]));
      await refresh;
      await tester.pump();
      expect(find.text('Updated poster'), findsWidgets);
      expect(find.text('Extra page poster'), findsWidgets);
      expect(find.text('New poster'), findsWidgets);
      expect(scroll.position.pixels, offset);
      refreshing = false;
      await tester.drag(row, const Offset(-300, 0));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(requestedPages, containsAllInOrder(['2', '1', '3']));
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/movie/now_playing')) {
                return response([]);
              }
              final page = request.url.queryParameters['page']!;
              requestedPages.add(page);
              if (refreshing) return pending.future;
              return response([
                {'id': int.parse(page) + 10, 'title': 'Extra page poster'}
              ]);
            }));
  });

  testWidgets('failed refresh keeps posters and offers a working retry',
      (tester) async {
    var fail = true;
    await http.runWithClient(() async {
      await openHome(tester);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.text('Original poster'), findsOneWidget);
      expect(find.text('Couldn’t refresh. Your loaded movies are still here.'),
          findsOneWidget);
      fail = false;
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Retry').last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Updated poster'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/movie/now_playing')) {
                return response([]);
              }
              if (fail) return http.Response('Unavailable', 503);
              return response([
                {'id': 1, 'title': 'Updated poster'}
              ]);
            }));
  });
}
