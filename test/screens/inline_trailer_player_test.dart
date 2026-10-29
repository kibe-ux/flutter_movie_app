import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:moviehub_app/models/movie_more_info.dart';
import 'package:moviehub_app/widgets/movie_trailers.dart';
import 'package:moviehub_app/widgets/inline_trailer_player.dart';
import '../helpers/fake_trailer_webview.dart';

void main() {
  late FakeTrailerWebView platform;
  final videos = MovieInfoVideo.fromDetails({
    'videos': [
      {
        'site': 'YouTube',
        'key': 'abcdefghijk',
        'name': 'Official trailer',
        'type': 'Trailer'
      },
      {'site': 'Vimeo', 'key': '123456', 'name': 'Teaser', 'type': 'Teaser'},
    ]
  });
  setUp(() {
    platform = FakeTrailerWebView();
    WebViewPlatform.instance = platform;
  });
  Widget app() => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
          body: SingleChildScrollView(child: MovieTrailers(videos: videos))));

  testWidgets(
      'plays one inline video, switches sources and closes without navigation',
      (tester) async {
    await tester.pumpWidget(app());
    expect(
        tester
            .widget<ListView>(
                find.byKey(const PageStorageKey('movie-videos-row')))
            .scrollDirection,
        Axis.horizontal);
    await tester.tap(find.text('Official trailer'));
    await tester.pumpAndSettle();
    expect(find.byType(InlineTrailerPlayer), findsOneWidget);
    expect(platform.controllers.single.requests.single.uri.host,
        'www.youtube.com');
    expect(platform.controllers.single.requests.single.headers['Referer'],
        'https://com.moviehub.app/');
    expect(find.text('Open in YouTube'), findsNothing);
    await tester.ensureVisible(find.text('Teaser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teaser'));
    await tester.pumpAndSettle();
    expect(find.byType(InlineTrailerPlayer), findsOneWidget);
    expect(platform.controllers, hasLength(2));
    expect(platform.controllers.first.document, contains('<html>'));
    expect(
        platform.controllers.last.requests.single.uri.host, 'player.vimeo.com');
    await tester.ensureVisible(find.text('Close player'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close player'));
    await tester.pumpAndSettle();
    expect(find.byType(InlineTrailerPlayer), findsNothing);
    expect(platform.controllers.last.document, contains('<html>'));
  });

  testWidgets('loading timeout offers in-app retry', (tester) async {
    platform.completeLoads = false;
    await tester.pumpWidget(app());
    await tester.tap(find.text('Official trailer'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 26));
    expect(find.text('Retry trailer'), findsOneWidget);
    await tester.tap(find.text('Retry trailer'));
    await tester.pump();
    expect(platform.controllers.single.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pauses on app background and prevents leaving through native URL schemes',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Official trailer'));
    await tester.pumpAndSettle();
    final controller = platform.controllers.single;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(controller.scripts.last, contains('pause'));
    final decision = await controller.navigation!.navigate!(
        const NavigationRequest(url: 'intent://video', isMainFrame: true));
    expect(decision, NavigationDecision.prevent);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
