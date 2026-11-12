import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/widgets/fast_page_transitions.dart';

void main() {
  testWidgets('screen push and pop finish within the shorter animation budgets',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          platform: TargetPlatform.android,
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: FastPageTransitionsBuilder(),
          })),
      home: Builder(
          builder: (context) => Scaffold(
              body: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (context) => Scaffold(
                              body: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Text('Back'))))),
                  child: const Text('Open details')))),
    ));
    await tester.tap(find.text('Open details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('Back'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(find.text('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
