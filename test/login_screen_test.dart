import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/login_screen.dart';

void main() {
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
