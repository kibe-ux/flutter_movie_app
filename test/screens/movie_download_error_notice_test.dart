import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/films365_api_service.dart';
import 'package:moviehub_app/widgets/movie_download_error_notice.dart';

void main() {
  const denial = Films365RequestException(401, source: 'films365');

  Widget app(VoidCallback onRetry) => MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showMovieDownloadError(context, denial,
                          onRetry: onRetry),
                      child: const Text('Download'),
                    ))),
      );

  testWidgets('download error expires with Retry present', (tester) async {
    await tester.pumpWidget(app(() {}));
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Retry invokes the new attempt and closes the message',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(app(() => retries++));
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retries, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('repeated errors replace each other instead of accumulating',
      (tester) async {
    await tester.pumpWidget(app(() {}));
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
