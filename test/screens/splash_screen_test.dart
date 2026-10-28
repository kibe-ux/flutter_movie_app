import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/splash_screen.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:moviehub_app/services/home_startup_service.dart';
import 'package:moviehub_app/widgets/auth_wrapper.dart';
import 'package:moviehub_app/services/catalogue_service.dart';
import 'package:provider/provider.dart';

// Keep the destination at its auth gate so these tests only exercise startup.
class _LoadingAuth extends ChangeNotifier implements AuthService {
  @override
  bool get isLoading => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledStartup extends HomeStartupService {
  final data = Completer<HomeStartupData>();
  final images = Completer<void>();
  bool preloading = false;

  @override
  Future<HomeStartupData> load() => data.future;

  @override
  Future<void> preloadImages(HomeStartupData data, BuildContext context) {
    preloading = true;
    return images.future;
  }
}

class _RetryableStartup extends HomeStartupService {
  int attempts = 0;

  @override
  Future<HomeStartupData> load() async {
    if (++attempts == 1) {
      throw const CatalogueLoadException(
          'Check your connection and try again.');
    }
    return const HomeStartupData(connected: true, categories: {});
  }

  @override
  Future<void> preloadImages(
      HomeStartupData data, BuildContext context) async {}
}

void main() {
  testWidgets('shows splash immediately and waits for initialization',
      (tester) async {
    final ready = Completer<void>();
    var initializationCount = 0;
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>(
      create: (_) => _LoadingAuth(),
      child: MaterialApp(
        home: SplashScreen(initialize: () {
          initializationCount++;
          return ready.future;
        }),
      ),
    ));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(initializationCount, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AuthWrapper), findsNothing);

    ready.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AuthWrapper), findsOneWidget);
    expect(initializationCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fast initialization keeps the cinematic splash visible first',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>(
      create: (_) => _LoadingAuth(),
      child: MaterialApp(home: SplashScreen(initialize: () async {})),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AuthWrapper), findsNothing);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    expect(find.byType(AuthWrapper), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AuthWrapper), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waits for movie data but opens Home without waiting for artwork',
      (tester) async {
    final startup = _ControlledStartup();
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>(
      create: (_) => _LoadingAuth(),
      child: MaterialApp(
          home: SplashScreen(
        initialize: () async {},
        startupService: startup,
      )),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AuthWrapper), findsNothing);
    expect(startup.preloading, isFalse);
    startup.data
        .complete(const HomeStartupData(connected: true, categories: {}));
    await tester.pump();
    expect(startup.preloading, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AuthWrapper), findsOneWidget);
    startup.images.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(AuthWrapper), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('artwork failure does not block opening Home', (tester) async {
    final startup = _ControlledStartup();
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>(
        create: (_) => _LoadingAuth(),
        child: MaterialApp(
            home: SplashScreen(
          initialize: () async {},
          startupService: startup,
        ))));
    startup.data
        .complete(const HomeStartupData(connected: true, categories: {}));
    await tester.pump();
    startup.images.completeError(StateError('Poster download failed'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    expect(find.byType(AuthWrapper), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'feed retry keeps successful initialization and explains the error',
      (tester) async {
    final startup = _RetryableStartup();
    var initializationCount = 0;
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>(
      create: (_) => _LoadingAuth(),
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: SplashScreen(
          initialize: () async {
            initializationCount++;
          },
          startupService: startup,
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(initializationCount, 1);
    expect(startup.attempts, 2);
    expect(find.byType(AuthWrapper), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup failures remain on splash and can be retried',
      (tester) async {
    final retry = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      // Avoid loading a GPU shader when exercising the retry tap in tests.
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: SplashScreen(initialize: () {
        if (++attempts == 1) throw StateError('Initialization failed');
        return retry.future;
      }),
    ));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(AuthWrapper), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Retry'), findsNothing);

    // Completion after disposal must not navigate or update a removed screen.
    await tester.pumpWidget(const SizedBox());
    retry.complete();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
