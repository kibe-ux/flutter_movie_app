import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import '../services/download_service.dart';
import '../services/tv_series_service.dart';
import '../utils/movie_download_availability.dart';
import 'safe_network_image.dart';

class TvSeasonsSection extends StatefulWidget {
  const TvSeasonsSection(
      {super.key,
      required this.seriesId,
      required this.metadata,
      required this.onDownload,
      required this.onRefresh,
      this.service,
      this.downloadService,
      this.seriesTitle = 'TV Series',
      this.posterPath});

  final int seriesId;
  final String seriesTitle;
  final String? posterPath;
  final Future<Map<String, dynamic>?> metadata;
  final void Function(int season, Map<String, dynamic> episode) onDownload;
  final VoidCallback onRefresh;
  final TvSeriesService? service;
  final DownloadService? downloadService;

  @override
  State<TvSeasonsSection> createState() => _TvSeasonsSectionState();
}

class _TvSeasonsSectionState extends State<TvSeasonsSection> {
  late final TvSeriesService _service = widget.service ?? TvSeriesService();
  late final DownloadService _downloads =
      widget.downloadService ?? DownloadService();
  List<Map<String, dynamic>>? _seasons;
  bool _failed = false;
  int? _selected;
  Future<List<Map<String, dynamic>>>? _episodes;
  final Map<int, Future<List<Map<String, dynamic>>>> _cache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _seasons = null;
    });
    try {
      final seasons = await _service.seasons(widget.seriesId);
      seasons.sort((a, b) {
        final x = (a['season_number'] as num).toInt();
        final y = (b['season_number'] as num).toInt();
        return (x == 0 ? 99999 : x).compareTo(y == 0 ? 99999 : y);
      });
      if (!mounted) return;
      setState(() => _seasons = seasons);
      if (seasons.isNotEmpty) {
        _select((seasons.first['season_number'] as num).toInt());
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _select(int season, {bool retry = false}) {
    if (retry) _cache.remove(season);
    setState(() {
      _selected = season;
      _episodes = _cache.putIfAbsent(season, () async {
        final episodes = await _service.episodes(widget.seriesId, season);
        for (final episode in episodes) {
          final code =
              'S${season.toString().padLeft(2, '0')}E${episode['episode_number'].toString().padLeft(2, '0')}';
          unawaited(_downloads
              .refreshDownloadStatus(
                movieId: episodeDownloadId((episode['id'] as num).toInt()),
                movieTitle:
                    '${widget.seriesTitle} $code - ${episode['name'] ?? 'Episode'}',
                posterPath: widget.posterPath,
              )
              .catchError((Object _) {}));
        }
        return episodes;
      });
    });
  }

  Widget _message(String text, {VoidCallback? retry}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Text(text, style: const TextStyle(color: CinemaPalette.muted)),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Retry'))
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Seasons & episodes',
          style: TextStyle(
              color: CinemaPalette.ivory,
              fontSize: 23,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Choose a season, then an episode to save offline.',
          style: TextStyle(color: CinemaPalette.muted, height: 1.5)),
      if (_failed)
        _message('Unable to load seasons.', retry: _load)
      else if (_seasons == null)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()))
      else if (_seasons!.isEmpty)
        _message('Season information is not available yet.')
      else ...[
        const SizedBox(height: 18),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: _seasons!.map((season) {
              final number = (season['season_number'] as num).toInt();
              return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: number == _selected,
                    selectedColor: CinemaPalette.gold,
                    labelStyle: TextStyle(
                        color: number == _selected
                            ? CinemaPalette.background
                            : CinemaPalette.ivory),
                    label: Text(number == 0 ? 'Specials' : 'Season $number'),
                    onSelected: (_) => _select(number),
                  ));
            }).toList())),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
            future: _episodes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return _message('Unable to load episodes.',
                    retry: () => _select(_selected!, retry: true));
              }
              final episodes = snapshot.data ?? [];
              if (episodes.isEmpty) {
                return _message('No episodes announced for this season.');
              }
              return FutureBuilder<Map<String, dynamic>?>(
                  future: widget.metadata,
                  builder: (context, metadata) {
                    return StreamBuilder<Map<int, DownloadItem>>(
                        stream: _downloads.downloadsStream,
                        initialData: _downloads.activeDownloads,
                        builder: (context, downloads) {
                          return Column(children: [
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Text('${episodes.length} episodes',
                                    style: const TextStyle(
                                        color: CinemaPalette.muted))),
                            const SizedBox(height: 12),
                            for (final episode in episodes)
                              _episodeCard(
                                  episode,
                                  metadata.data,
                                  metadata.connectionState !=
                                      ConnectionState.done,
                                  downloads.data ?? {}),
                            TextButton.icon(
                                onPressed: widget.onRefresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text(
                                    'Refresh download availability')),
                          ]);
                        });
                  });
            }),
      ],
    ]);
  }

  Widget _episodeCard(
      Map<String, dynamic> episode,
      Map<String, dynamic>? metadata,
      bool checking,
      Map<int, DownloadItem> downloads) {
    final number = (episode['episode_number'] as num).toInt();
    final id = episodeDownloadId((episode['id'] as num).toInt());
    final task = downloads[id];
    final future = isFutureMovieRelease(episode['air_date']);
    final available =
        episodeDownloadMetadata(metadata, _selected!, number) != null;
    final downloading = task?.status == DownloadStatus.downloading;
    final completed = task?.status == DownloadStatus.completed;
    final label = future
        ? 'Coming soon'
        : downloading
            ? '${(task!.progress * 100).round()}% · Pause'
            : completed
                ? 'Downloaded'
                : checking
                    ? 'Checking availability…'
                    : available
                        ? 'Download episode'
                        : 'Download unavailable';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: CinemaPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10)),
      child: LayoutBuilder(
          builder: (context, constraints) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (constraints.maxWidth > 430) ...[
                    SizedBox(
                        width: 132,
                        child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: SafeNetworkImage(
                                imageUrl: episode['still_path'] == null
                                    ? null
                                    : 'https://image.tmdb.org/t/p/w300${episode['still_path']}',
                                borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('EPISODE $number',
                            style: const TextStyle(
                                color: CinemaPalette.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 6),
                        Text(episode['name']?.toString() ?? 'Episode $number',
                            style: const TextStyle(
                                color: CinemaPalette.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            [
                              if (episode['runtime'] is num)
                                '${episode['runtime']} min',
                              if (episode['air_date'] != null)
                                '${episode['air_date']}'
                            ].join(' · '),
                            style: const TextStyle(
                                color: CinemaPalette.muted, fontSize: 12)),
                      ])),
                ]),
                if ((episode['overview']?.toString() ?? '').isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(episode['overview'].toString(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: CinemaPalette.muted, height: 1.5))),
                const SizedBox(height: 10),
                if (downloading)
                  LinearProgressIndicator(
                      value: task!.progress, color: CinemaPalette.gold),
                TextButton.icon(
                  onPressed: future || checking || completed
                      ? null
                      : downloading
                          ? () => _downloads.pauseDownload(id)
                          : available
                              ? () => widget.onDownload(_selected!, episode)
                              : null,
                  icon: Icon(
                      completed
                          ? Icons.check_circle_outline
                          : downloading
                              ? Icons.pause
                              : Icons.download_outlined,
                      size: 20),
                  label: Text(label),
                ),
                if (task?.errorMessage != null)
                  Text(task!.errorMessage!,
                      style: const TextStyle(color: Colors.orangeAccent)),
              ])),
    );
  }
}
