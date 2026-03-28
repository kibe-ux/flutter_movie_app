import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MovieDownloadApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
  });
}
