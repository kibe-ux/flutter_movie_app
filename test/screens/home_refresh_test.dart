import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/screens/home_screen.dart';
import 'package:moviehub_app/services/home_startup_service.dart';

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'MOVIE_API_KEY=test');
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

  testWidgets('refresh keeps extra pages, row position and pagination progress',
      (tester) async {
    final requestedPages = <String>[];
    var refreshing = false;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await openHome(tester);
      await tester.tap(find.text('Load More').first);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.text('Extra page poster'), findsOneWidget);
      final row = find.byKey(const PageStorageKey('home-posters-Now Playing'));
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
      expect(find.text('Extra page poster'), findsOneWidget);
      pending.complete(response([
        {'id': 1, 'title': 'Updated poster'},
        {'id': 3, 'title': 'New poster'}
      ]));
      await refresh;
      await tester.pump();
      expect(find.text('Updated poster'), findsOneWidget);
      expect(find.text('Extra page poster'), findsOneWidget);
      expect(find.text('New poster'), findsOneWidget);
      expect(scroll.position.pixels, offset);
      refreshing = false;
      await tester.drag(row, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load More').first);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(requestedPages, containsAllInOrder(['2', '1', '3']));
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path != '/3/movie/now_playing') {
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
      expect(find.text('Updated poster'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.url.path != '/3/movie/now_playing') {
                return response([]);
              }
              if (fail) return http.Response('Unavailable', 503);
              return response([
                {'id': 1, 'title': 'Updated poster'}
              ]);
            }));
  });
}
