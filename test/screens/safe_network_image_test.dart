// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:file/local.dart';
import 'package:moviehub_app/widgets/safe_network_image.dart';

class _ImageCache extends Fake implements BaseCacheManager {
  int requests = 0;
  @override
  Future<void> removeFile(String key) async {}

  @override
  Stream<FileResponse> getFileStream(String url,
      {String? key,
      Map<String, String>? headers,
      bool withProgress = false}) async* {
    requests++;
    if (requests == 1) throw StateError('Offline');
    yield FileInfo(const LocalFileSystem().file('assets/images/splash.jpg'),
        FileSource.Cache, DateTime.now().add(const Duration(hours: 1)), url);
  }
}

void main() {
  testWidgets('failed poster can be retried without reopening its screen',
      (tester) async {
    final cache = _ImageCache();
    // Assign before reading the lazy default so this isolated test does not
    // initialize a real disk cache or require path_provider platform plugins.
    CachedNetworkImageProvider.defaultCacheManager = cache;
    Future<void> advanceUntil(bool Function() done) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
          if (done()) break;
        }
      });
    }

    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 120,
      height: 160,
      child:
          SafeNetworkImage(imageUrl: 'https://posters.example/retry-test.jpg'),
    ))));
    await advanceUntil(() => find
        .byTooltip('Image unavailable. Tap to retry')
        .evaluate()
        .isNotEmpty);
    expect(find.byTooltip('Image unavailable. Tap to retry'), findsOneWidget);
    await tester.tap(find.byTooltip('Image unavailable. Tap to retry'));
    await advanceUntil(() =>
        cache.requests >= 2 &&
        find.byTooltip('Image unavailable. Tap to retry').evaluate().isEmpty);
    expect(cache.requests, 2);
    expect(find.byTooltip('Image unavailable. Tap to retry'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
