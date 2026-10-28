import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/widgets/connection_notice.dart';

void main() {
  testWidgets('retry is guarded while a connection check is pending',
      (tester) async {
    final pending = Completer<void>();
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ConnectionNotice(
          offline: true,
          title: 'You’re offline',
          message: 'Connect to Wi-Fi or mobile data to browse movies.',
          onRetry: () {
            retries++;
            return pending.future;
          },
        ),
      ),
    ));
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Checking connection…'));
    expect(retries, 1);
    expect(find.text('View downloads'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'recovery actions are reachable on a small screen with large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: ConnectionNotice(
          offline: true,
          title: 'You’re offline',
          message:
              'Connect to Wi-Fi or mobile data to explore movies and shows, then try again.',
          onRetry: () async {
            retries++;
          },
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
