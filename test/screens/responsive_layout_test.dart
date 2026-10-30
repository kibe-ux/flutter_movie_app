import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/screens/full_category_screen.dart';
import 'package:moviehub_app/screens/home_screen.dart';
import 'package:moviehub_app/services/home_startup_service.dart';
import 'package:moviehub_app/widgets/movie_hub_app_bar.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'MOVIE_API_KEY=test'));

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget child, double scale) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: child,
      );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('category fits $size with text scale $scale', (tester) async {
        await resize(tester, size);
        await tester.pumpWidget(app(
          FullCategoryScreen(
            title: 'A long movie category title for smaller screens',
            items: List.generate(
                20,
                (id) => {
                      'id': id,
                      'title':
                          'A long movie title that needs two lines of text',
                      'vote_average': 8.5,
                      'release_date': '2020-01-01',
                    }),
          ),
          scale,
        ));
        expect(tester.takeException(), isNull);

        // Rotating an existing screen must recalculate the grid immediately.
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final connected in [false, true]) {
    testWidgets('home fits landscape when connected=$connected',
        (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => [connected ? 'wifi' : 'none'],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
        (_) async => null,
      );
      // Ads use a custom codec; no native ad is needed for layout tests.
      messenger.setMockMessageHandler(
        'plugins.flutter.io/google_mobile_ads',
        (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
      );
      addTearDown(() {
        for (final name in [
          'dev.fluttercommunity.plus/connectivity',
          'dev.fluttercommunity.plus/connectivity_status',
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(name), null);
        }
        messenger.setMockMessageHandler(
            'plugins.flutter.io/google_mobile_ads', null);
      });
      await resize(tester, const Size(844, 390));
      var id = 0;
      final requestedPaths = <String>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(app(
          const Scaffold(
            appBar: MovieHubAppBar(accountAction: Icon(Icons.person_outline)),
            bottomNavigationBar: SizedBox(height: 72),
            body: HomeScreen(myListIds: {}),
          ),
          2,
        ));
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        if (connected) {
          // Offscreen categories must not all fetch during startup.
          expect(requestedPaths.length, lessThan(12));
          await tester.drag(find.byType(ListView).first, const Offset(0, -200));
          await tester.pump();
          expect(find.text('View All'), findsWidgets);
          expect(tester.takeException(), isNull);
        } else {
          expect(find.text('You’re offline'), findsOneWidget);
        }
        await tester.tap(find.text('My List'));
        await tester.pump();
        await tester.pump();
        await tester.scrollUntilVisible(
            find.text('Your next movie night starts here'), 200,
            scrollable: find
                .descendant(
                    of: find.byKey(const PageStorageKey('saved-titles')),
                    matching: find.byType(Scrollable))
                .first);
        expect(find.text('Your next movie night starts here'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (connected) {
          requestedPaths.clear();
          await tester.pumpWidget(app(
              const HomeScreen(
                myListIds: {},
                initialData: HomeStartupData(connected: true, categories: {
                  'Trending Today': [
                    {'id': 500, 'title': 'Preloaded movie'}
                  ],
                  'Now Playing': [],
                  'Popular Movies': [],
                  'Top Rated': [],
                }),
              ),
              2));
          // Seeded content is available on the very first frame.
          expect(find.text('Preloaded movie'), findsWidgets);
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          for (final endpoint in HomeStartupService.endpoints.values) {
            expect(requestedPaths, isNot(contains('/3/$endpoint')));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();

          // An empty successful initial feed must still allow lazy rows to load.
          requestedPaths.clear();
          await tester.pumpWidget(app(
            const HomeScreen(
              myListIds: {},
              initialData: HomeStartupData(connected: true, categories: {
                'Trending Today': [],
                'Now Playing': [],
                'Popular Movies': [],
                'Top Rated': [],
              }),
            ),
            2,
          ));
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(requestedPaths, contains('/3/discover/movie'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      },
          () => MockClient((request) async {
                requestedPaths.add(request.url.path);
                return http.Response(
                  jsonEncode({
                    'results': [
                      {
                        'id': ++id,
                        'title':
                            'A movie title long enough to wrap onto two lines',
                        'release_date': '2020-01-01',
                      },
                    ],
                  }),
                  200,
                );
              }));
    });
  }
}
