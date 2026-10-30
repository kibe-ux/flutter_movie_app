import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/login_screen.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:provider/provider.dart';

class _GoogleAuth extends ChangeNotifier implements AuthService {
  final response = Completer<UserCredential?>();
  int calls = 0;
  @override
  Future<UserCredential?> signInWithGoogle() {
    calls++;
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UserCredential extends Fake implements UserCredential {}

void main() {
  Future<void> openLogin(WidgetTester tester, _GoogleAuth auth,
      {ValueChanged<bool?>? onResult}) async {
    await tester.pumpWidget(ChangeNotifierProvider<AuthService>.value(
      value: auth,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()));
                        onResult?.call(result);
                      },
                      child: const Text('Open sign-in'),
                    ),
                  ))),
    ));
    await tester.tap(find.text('Open sign-in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  testWidgets('Google cancellation keeps login open and allows retry',
      (tester) async {
    final auth = _GoogleAuth();
    addTearDown(auth.dispose);
    await openLogin(tester, auth);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(auth.calls, 1);
    expect(find.text('Connecting to Google...'), findsOneWidget);
    auth.response.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Please enter your email'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful Google sign-in returns true to the requested action',
      (tester) async {
    final auth = _GoogleAuth();
    addTearDown(auth.dispose);
    bool? result;
    await openLogin(tester, auth, onResult: (value) => result = value);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    auth.response.complete(_UserCredential());
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Google network errors give a readable message and allow retry',
      (tester) async {
    final auth = _GoogleAuth();
    addTearDown(auth.dispose);
    await openLogin(tester, auth);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    auth.response
        .completeError(FirebaseAuthException(code: 'network-request-failed'));
    await tester.pumpAndSettle();
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'continue as guest dismisses sign-in without validating credentials',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  )),
                  child: const Text('Open sign-in'),
                ),
              )),
    ));
    await tester.tap(find.text('Open sign-in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue as guest'));
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Open sign-in'), findsOneWidget);
    expect(find.text('Please enter your email'), findsNothing);
  });

  testWidgets('accepts trimmed email addresses with long domain suffixes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(
      find.byType(TextFormField).first,
      ' person@example.technology ',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsNothing);
    expect(find.text('Please enter a valid email'), findsNothing);
  });
}
