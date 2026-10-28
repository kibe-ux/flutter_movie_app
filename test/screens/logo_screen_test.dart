import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/logo_screen.dart';
import 'package:moviehub_app/screens/splash_screen.dart';
import 'package:moviehub_app/widgets/movie_hub_icon.dart';

void main() {
  testWidgets('black logo appears before splash and initialization',
      (tester) async {
    var starts = 0;
    final ready = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: LogoScreen(initialize: () {
      starts++;
      return ready.future;
    })));
    expect(find.byType(MovieHubIcon), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.black);
    expect(find.byType(SplashScreen), findsNothing);
    expect(starts, 0);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(MovieHubIcon), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(MovieHubIcon), findsNothing);
    expect(starts, 1);
    await tester.pumpWidget(const SizedBox());
    ready.complete();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing logo cancels transition', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LogoScreen()));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
