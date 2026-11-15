import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/faqs_screen.dart';

void main() {
  testWidgets('FAQ topics, expanded answers and empty-search recovery work',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FAQsScreen()));
    expect(find.widgetWithText(ChoiceChip, 'Downloads'), findsNothing);
    final account = find.widgetWithText(ChoiceChip, 'Account');
    await tester.ensureVisible(account);
    await tester.tap(account);
    await tester.pumpAndSettle();
    expect(find.text('3 questions'), findsOneWidget);
    final question = find.text('Do I need an account to explore Movie Hub?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('You can browse as a guest.'), findsOneWidget);
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
