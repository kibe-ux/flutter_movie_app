import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_hub/main.dart';
void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlixoraApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Flixora X'), findsOneWidget);
  });
}