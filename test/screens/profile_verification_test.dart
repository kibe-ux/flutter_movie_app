import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moviehub_app/screens/profile_screen.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:moviehub_app/widgets/email_verification_notice.dart';

class _User extends Fake implements User {
  @override
  String get email => 'viewer@example.com';
  @override
  String? get displayName => null;
  @override
  String? get photoURL => null;
}

class _Auth extends ChangeNotifier implements AuthService {
  bool verified = false;
  bool remoteVerified = false;
  int reloads = 0;
  int emails = 0;

  @override
  User get currentUser => _User();
  @override
  bool get isAuthenticated => true;
  @override
  bool get isEmailVerified => verified;
  @override
  Future<void> reloadCurrentUser() async {
    reloads++;
    verified = remoteVerified;
    notifyListeners();
  }

  @override
  Future<void> sendEmailVerification() async {
    emails++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _showProfile(WidgetTester tester, _Auth auth) async {
  await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
    value: auth,
    child: const MaterialApp(home: ProfileScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening profile refreshes a previously stale verification flag',
      (tester) async {
    final auth = _Auth()..remoteVerified = true;
    addTearDown(auth.dispose);
    await _showProfile(tester, auth);
    expect(auth.reloads, 1);
    expect(find.text('Email verified'), findsOneWidget);
    expect(find.byType(EmailVerificationNotice), findsNothing);
    expect(auth.emails, 0);
  });

  testWidgets('returning from email rechecks the verified status',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    await _showProfile(tester, auth);
    expect(find.text('Confirm your email'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    auth.remoteVerified = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.reloads, 2);
    expect(find.text('Email verified'), findsOneWidget);
    expect(auth.emails, 0);
  });

  testWidgets('sending verification does not mark the account verified',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    await _showProfile(tester, auth);
    await tester.ensureVisible(find.text('Send verification'));
    await tester.tap(find.text('Send verification'));
    await tester.pumpAndSettle();
    expect(auth.emails, 1);
    expect(auth.verified, isFalse);
    await tester.ensureVisible(find.text('Check status'));
    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();
    expect(auth.reloads, 2);
    expect(auth.verified, isFalse);
    expect(find.text('Confirm your email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
