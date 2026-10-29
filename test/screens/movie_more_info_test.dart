import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/widgets/movie_more_info.dart';
import 'package:moviehub_app/widgets/inline_trailer_player.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../helpers/fake_trailer_webview.dart';

void main() {
  setUp(() => WebViewPlatform.instance = FakeTrailerWebView());
  final details = <String, dynamic>{
    'genres': ['Action', 'Adventure'],
    'casts': [
      {'name': 'Lead Actor', 'character': 'The Hero'}
    ],
    'crew': [
      {'name': 'Film Director', 'job': 'Director'}
    ],
    'videos': [
      {
        'site': 'YouTube',
        'key': 'abcdefghijk',
        'name': 'Official trailer',
        'type': 'Trailer'
      },
      {
        'site': 'Vimeo',
        'key': '123456',
        'name': 'Making the movie',
        'type': 'Featurette'
      },
    ],
    'runtime': 123,
    'id': 'private-provider-id',
    'tmdbId': 987654321,
    'imdbId': 'tt123456789',
    'spokenLanguages': ['English'],
    'productionCompanies': ['Example Pictures'],
    'watchProviders': {
      'results': {
        'US': {
          'buy': [
            {'provider_name': 'Amazon Video', 'provider_id': 1},
            {'provider_name': 'Google Play Movies', 'provider_id': 2},
          ],
          'flatrate': [
            {'provider_name': 'Amazon Prime Video', 'provider_id': 3}
          ]
        },
        'GB': {
          'rent': [
            {'provider_name': 'Rakuten TV', 'provider_id': 4}
          ]
        },
      }
    },
  };

  Widget app(Future<Map<String, dynamic>?> metadata,
          {VoidCallback? onRetry, double scale = 1}) =>
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(20),
          child: MovieMoreInfo(
            movieId: 42,
            metadata: metadata,
            onRetry: onRetry ?? () {},
          ),
        ))),
      );

  Future<void> expand(WidgetTester tester, String name) async {
    final title = find.text(name);
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows Details cast, crew, videos and providers without another API request',
      (tester) async {
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(app(Future.value(details)));
      await tester.pumpAndSettle();
      expect(find.text('More info'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      await expand(tester, 'Cast');
      expect(find.text('Lead Actor'), findsOneWidget);
      expect(find.text('The Hero'), findsOneWidget);
      await expand(tester, 'Crew');
      expect(find.text('Film Director'), findsOneWidget);
      expect(find.text('Director'), findsOneWidget);
      await expand(tester, 'Trailers & videos');
      await tester.ensureVisible(find.text('Official trailer'));
      await tester.tap(find.text('Official trailer'));
      await tester.pump();
      expect(
          tester
              .widget<InlineTrailerPlayer>(find.byType(InlineTrailerPlayer))
              .video
              .youtubeKey,
          'abcdefghijk');
      await tester.ensureVisible(find.text('Making the movie'));
      await tester.tap(find.text('Making the movie'));
      await tester.pump();
      expect(
          tester
              .widget<InlineTrailerPlayer>(find.byType(InlineTrailerPlayer))
              .video
              .site,
          'Vimeo');
      await tester.ensureVisible(find.text('Close player'));
      await tester.tap(find.text('Close player'));
      await tester.pumpAndSettle();
      await expand(tester, 'Additional info');
      expect(find.text('123 min'), findsOneWidget);
      expect(find.text('Example Pictures'), findsOneWidget);
      expect(find.text('IMDb ID'), findsNothing);
      expect(find.text('tt123456789'), findsNothing);
      expect(find.textContaining('private-provider-id'), findsNothing);
      expect(find.textContaining('987654321'), findsNothing);
      expect(find.text('Amazon Video'), findsOneWidget);
      expect(find.text('Amazon Prime Video'), findsOneWidget);
      expect(find.text('Google Play Movies'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GB').last);
      await tester.pumpAndSettle();
      expect(find.text('Rakuten TV'), findsOneWidget);
      expect(find.text('Amazon Video'), findsNothing);
      expect(requests, 0);
    },
        () => MockClient((_) async {
              requests++;
              return http.Response('{}', 500);
            }));
  });

  testWidgets('cast and crew scroll horizontally to later people',
      (tester) async {
    await tester.pumpWidget(app(Future.value({
      ...details,
      'casts':
          List.generate(8, (i) => {'name': 'Actor $i', 'character': 'Role $i'}),
      'crew': List.generate(8, (i) => {'name': 'Crew $i', 'job': 'Job $i'}),
    })));
    await tester.pumpAndSettle();
    for (final entry in [
      ('Cast', 'movie-cast-row', 'Actor 7'),
      ('Crew', 'movie-crew-row', 'Crew 7')
    ]) {
      await expand(tester, entry.$1);
      final row = find.byKey(PageStorageKey(entry.$2));
      expect(tester.widget<ListView>(row).scrollDirection, Axis.horizontal);
      await tester.ensureVisible(row);
      await tester.scrollUntilVisible(find.text(entry.$3), 200,
          scrollable:
              find.descendant(of: row, matching: find.byType(Scrollable)));
      await tester.pumpAndSettle();
      expect(find.text(entry.$3).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('loads once and offers retry when Details are unavailable',
      (tester) async {
    final pending = Completer<Map<String, dynamic>?>();
    var retries = 0;
    await tester.pumpWidget(app(pending.future, onRetry: () => retries++));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('More info could not be loaded. Please try again.'),
        findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('empty Details fields do not invent providers or video links',
      (tester) async {
    await tester.pumpWidget(app(Future.value({'id': 'movie'})));
    await tester.pumpAndSettle();
    await expand(tester, 'Trailers & videos');
    expect(find.text('No trailers or videos supplied.'), findsOneWidget);
    expect(find.text('Amazon Video'), findsNothing);
    expect(find.textContaining('No viewing options listed'), findsOneWidget);
  });

  testWidgets('More info fits a small screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(Future.value(details), scale: 2));
    await tester.pumpAndSettle();
    for (final section in [
      'Cast',
      'Crew',
      'Trailers & videos',
      'Additional info'
    ]) {
      await expand(tester, section);
      expect(tester.takeException(), isNull);
    }
  });
}
