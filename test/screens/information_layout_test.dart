import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/faqs_screen.dart';
import 'package:moviehub_app/screens/legal_info_screen.dart';
import 'package:moviehub_app/screens/legal_screen.dart';
import 'package:moviehub_app/screens/privacy_policy_screen.dart';
import 'package:moviehub_app/screens/share_screen.dart';
import 'package:moviehub_app/screens/support_screen.dart';

void main() {
  final pages = <String, Widget>{
    'FAQs': const FAQsScreen(),
    'Share app': const ShareScreen(),
    'Privacy': const PrivacyPolicyScreen(),
    'About': const LegalInfoScreen(type: LegalPageType.about),
    'Terms': const LegalInfoScreen(type: LegalPageType.terms),
    'Copyright': const LegalInfoScreen(type: LegalPageType.copyright),
    'Disclaimer': const LegalScreen(),
    'Support': const SupportScreen(),
  };
  const sizes = [
    Size(320, 568),
    Size(568, 320),
    Size(1024, 768),
    Size(1440, 900),
  ];

  Widget app(Widget page, double scale) => MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      );

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final entry in pages.entries) {
    for (final size in sizes) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${entry.key} fits $size at text scale $scale',
            (tester) async {
          await resize(tester, size);
          await tester.pumpWidget(app(entry.value, scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scroll = find.byType(Scrollable).first;
          for (var step = 0; step < 60; step++) {
            final position = tester.state<ScrollableState>(scroll).position;
            if (position.extentAfter <= 0) break;
            await tester.drag(scroll, Offset(0, -size.height * .65));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          tester.view.physicalSize = Size(size.height, size.width);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final label in ['Report Bug', 'Request Movie']) {
    for (final size in sizes.take(2)) {
      testWidgets('$label form fits $size with keyboard and large text',
          (tester) async {
        await resize(tester, size);
        await tester.pumpWidget(app(const SupportScreen(), 2));
        await tester.scrollUntilVisible(find.text(label), 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
