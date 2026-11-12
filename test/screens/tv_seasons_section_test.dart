import 'package:moviehub_app/models/download_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/download_service.dart';
import 'package:moviehub_app/services/tv_series_service.dart';
import 'package:moviehub_app/widgets/tv_seasons_section.dart';

class _Tv extends TvSeriesService {
  @override
  Future<List<Map<String, dynamic>>> seasons(int id) async => [
        {'season_number': 0},
        {'season_number': 1},
        {'season_number': 2},
      ];
  @override
  Future<List<Map<String, dynamic>>> episodes(int id, int season) async => [
        {
          'id': season * 100 + 1,
          'episode_number': 1,
          'name': season == 1 ? 'Pilot' : 'Finale',
          'air_date': '2020-01-01',
          'overview': 'An episode description.',
          'runtime': 42
        },
        {
          'id': season * 100 + 2,
          'episode_number': 2,
          'name': 'Next episode',
          'air_date': '2999-01-01'
        },
      ];
}

class _Downloads implements DownloadService {
  @override
  Stream<Map<int, DownloadItem>> get downloadsStream => const Stream.empty();
  @override
  Map<int, DownloadItem> get activeDownloads => {};
  @override
  Future<void> refreshDownloadStatus(
      {required int movieId,
      required String movieTitle,
      String? posterPath}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'matches episode files by season and episode and never uses a series URL',
      () {
    final details = {
      'downloadUrl': 'https://example.com/series',
      'seasons': [
        {
          'seasonNumber': 1,
          'episodes': [
            {'episodeNumber': 1, 'downloadUrl': 'https://example.com/one'},
            {'episodeNumber': 2, 'downloadUrl': 'magnet:invalid'},
          ]
        },
        {
          'seasonNumber': 2,
          'episodes': [
            {'episodeNumber': 1, 'downloadUrl': 'https://example.com/two'},
          ]
        },
      ]
    };
    expect(episodeDownloadMetadata(details, 1, 1)?['downloadUrl'],
        'https://example.com/one');
    expect(episodeDownloadMetadata(details, 2, 1)?['downloadUrl'],
        'https://example.com/two');
    expect(episodeDownloadMetadata(details, 1, 2), isNull);
    expect(episodeDownloadMetadata(details, 3, 1), isNull);
    expect(
        episodeDownloadMetadata(
            {'downloadUrl': 'https://example.com/series'}, 1, 1),
        isNull);
    expect(episodeDownloadId(101), isNot(episodeDownloadId(201)));
    expect(
        isTvSeries({'name': 'Series', 'first_air_date': '2020-01-01'}), isTrue);
    expect(isTvSeries({'media_type': 'movie', 'name': 'Movie'}), isFalse);
  });

  testWidgets(
      'on-demand episode actions do not require prefetched file metadata',
      (tester) async {
    var downloads = 0;
    var plays = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(
          body: ListView(children: [
        TvSeasonsSection(
          seriesId: 42,
          service: _Tv(),
          downloadService: _Downloads(),
          metadata: Future.value(null),
          resolveOnDemand: true,
          onRefresh: () {},
          onDownload: (season, episode) {
            expect(season, 1);
            expect(episode['episode_number'], 1);
            downloads++;
          },
          onPlay: (season, episode) {
            expect(season, 1);
            expect(episode['episode_number'], 1);
            plays++;
          },
        )
      ])),
    ));
    await tester.pumpAndSettle();
    expect(downloads, 0);
    expect(plays, 0);
    await tester.ensureVisible(find.text('Find episode download'));
    await tester.tap(find.text('Find episode download'));
    expect(downloads, 1);
    await tester.ensureVisible(find.text('Watch episode'));
    await tester.tap(find.text('Watch episode'));
    expect(plays, 1);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 844.0]) {
    testWidgets('seasons and episode actions fit width $width with large text',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selectedSeason;
      int? selectedEpisode;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
          TvSeasonsSection(
            seriesId: 42,
            service: _Tv(),
            downloadService: _Downloads(),
            metadata: Future.value({
              'seasons': [
                {
                  'season_number': 1,
                  'episodes': [
                    {
                      'episode_number': 1,
                      'downloadUrl': 'https://example.com/one'
                    }
                  ]
                },
              ]
            }),
            onRefresh: () {},
            onDownload: (season, episode) {
              selectedSeason = season;
              selectedEpisode = episode['episode_number'];
            },
          )
        ])),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pilot'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      await tester.ensureVisible(find.text('Download episode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download episode'));
      expect(selectedSeason, 1);
      expect(selectedEpisode, 1);
      await tester.ensureVisible(find.text('Season 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Season 2'));
      await tester.pumpAndSettle();
      expect(find.text('Finale'), findsOneWidget);
      expect(find.text('Download unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
