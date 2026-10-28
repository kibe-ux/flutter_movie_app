import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:moviehub_app/widgets/auth_wrapper.dart';
import 'package:moviehub_app/screens/profile_screen.dart';
import 'package:moviehub_app/screens/login_screen.dart';

class _GuestAuth extends ChangeNotifier implements AuthService {
  @override
  bool get isLoading => false;
  @override
  bool get isAuthenticated => false;
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('resolved signed-out startup shows content without login',
      (tester) async {
    final auth = _GuestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: const MaterialApp(
          home: AuthWrapper(
        child: Scaffold(body: Text('Browse movies')),
      )),
    ));
    expect(find.text('Browse movies'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
      'guest profile offers optional sign-in and allows returning as guest',
      (tester) async {
    final auth = _GuestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Browsing as guest'), findsOneWidget);
    expect(find.text('Account Settings'), findsNothing);
    await tester.tap(find.text('Sign In / Sign Up'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue as guest'));
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    expect(find.text('Browsing as guest'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });
}
