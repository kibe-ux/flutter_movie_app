import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/share_screen.dart';

void main() {
  testWidgets(
      'copied movie message includes the title without internal identifiers',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(const MaterialApp(
        home: ShareScreen(movie: {
      'title': 'Coco',
      'vote_average': 8.4,
      'id': 987654321,
      'tmdbId': 987654321,
      'films365_id': 'private-provider-id',
      'imdbId': 'tt123456789',
    })));
    await tester.ensureVisible(find.text('Copy message'));
    await tester.tap(find.text('Copy message'));
    await tester.pumpAndSettle();
    expect(copied, contains('Coco'));
    expect(copied, contains('Movie Hub Downloader'));
    for (final identifier in [
      '987654321',
      'private-provider-id',
      'tt123456789'
    ]) {
      expect(copied, isNot(contains(identifier)));
      expect(find.textContaining(identifier), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
