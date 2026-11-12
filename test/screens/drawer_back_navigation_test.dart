import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moviehub_app/screens/main_screen.dart';
import 'package:moviehub_app/screens/legal_info_screen.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:moviehub_app/services/home_startup_service.dart';

class _GuestAuth extends ChangeNotifier implements AuthService {
  @override
  User? get currentUser => null;
  @override
  String? get photoURL => null;
  @override
  String? get displayName => null;
  @override
  String? get email => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel(
                'dev.fluttercommunity.plus/connectivity_status'),
            (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel(
                'dev.fluttercommunity.plus/connectivity_status'),
            null);
  });

  for (final page in ['About Us', 'Terms of Service', 'Copyright Policy']) {
    for (final systemBack in [false, true]) {
      testWidgets(
          '$page returns to open drawer using ${systemBack ? 'system back' : 'back arrow'}',
          (tester) async {
        final auth = _GuestAuth();
        addTearDown(auth.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
            value: auth,
            child: const MaterialApp(
                home: MainScreen(
                    initialHomeData:
                        HomeStartupData(connected: false, categories: {})))));
        await tester.pumpAndSettle();
        final shell = tester.state<ScaffoldState>(find
            .descendant(
                of: find.byType(MainScreen), matching: find.byType(Scaffold))
            .first);
        shell.openDrawer();
        await tester.pumpAndSettle();
        final menuItem = find.widgetWithText(ListTile, page);
        await tester.ensureVisible(menuItem);
        await tester.tap(menuItem);
        await tester.pumpAndSettle();
        expect(find.byType(LegalInfoScreen), findsOneWidget);
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();
        expect(find.byType(LegalInfoScreen), findsNothing);
        expect(shell.isDrawerOpen, isTrue);
        expect(find.widgetWithText(ListTile, page), findsOneWidget);
        // A second Back closes the drawer without leaving the main screen.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(shell.isDrawerOpen, isFalse);
        expect(find.byType(MainScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
