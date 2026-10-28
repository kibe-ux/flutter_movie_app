import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/faqs_screen.dart';
import 'package:moviehub_app/widgets/rate_app_dialog.dart';

void main() {
  testWidgets('rating waits for confirmation and returns the selected value',
      (tester) async {
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<int>(
                      context: context,
                      builder: (_) => const RateAppDialog(),
                    );
                  },
                  child: const Text('Open rating'),
                ),
              )),
    ));
    await tester.tap(find.text('Open rating'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byTooltip('3 stars'));
    await tester.pumpAndSettle();
    expect(find.text("It's okay"), findsOneWidget);
    expect(find.byType(RateAppDialog), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(result, 3);
    expect(find.byType(RateAppDialog), findsNothing);
  });

  testWidgets('rating stays usable on a narrow screen with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: const Scaffold(body: RateAppDialog()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit rating'));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('FAQ topics, expanded answers and empty-search recovery work',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FAQsScreen()));
    final downloads = find.widgetWithText(ChoiceChip, 'Downloads');
    await tester.ensureVisible(downloads);
    await tester.tap(downloads);
    await tester.pumpAndSettle();
    expect(find.text('1 question'), findsOneWidget);
    final question =
        find.text('What should I check when playback or a download fails?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(
        find.textContaining(
            'Check your connection and available device storage'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TextField), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'zzznomatches');
    await tester.pumpAndSettle();
    expect(find.text('No matching questions'), findsOneWidget);
    await tester.ensureVisible(find.text('Show all questions'));
    await tester.tap(find.text('Show all questions'));
    await tester.pumpAndSettle();
    expect(find.text('Popular questions'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TextField), -200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All topics'))
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
  });
}
