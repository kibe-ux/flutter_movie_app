import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/login_screen.dart';

void main() {
  testWidgets('Login screen displays sign-in form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
