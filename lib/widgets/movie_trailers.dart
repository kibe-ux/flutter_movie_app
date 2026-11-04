import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import '../models/movie_more_info.dart';
import 'inline_trailer_player.dart';

class MovieTrailers extends StatefulWidget {
  const MovieTrailers({super.key, required this.videos});
  final List<MovieInfoVideo> videos;
  @override
  State<MovieTrailers> createState() => _MovieTrailersState();
}

class _MovieTrailersState extends State<MovieTrailers> {
  MovieInfoVideo? _selected;
  @override
  void didUpdateWidget(covariant MovieTrailers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.videos.any((video) => video.uri == _selected?.uri)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (selected != null) ...[
        InlineTrailerPlayer(key: ValueKey(selected.uri), video: selected),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.close),
                label: const Text('Close player'))),
      ],
      LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth * 0.85).clamp(160.0, 248.0);
        final scaler = MediaQuery.textScalerOf(context);
        final nameHeight = scaler.scale(14) * 1.3 * 2;
        final subtitleHeight = scaler.scale(12) * 1.3;
        return SizedBox(
          height: 100 + 24 + nameHeight + 6 + subtitleHeight + 2,
          child: ListView.separated(
            key: const PageStorageKey('movie-videos-row'),
            scrollDirection: Axis.horizontal,
            itemCount: widget.videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final video = widget.videos[index];
              final active = selected?.uri == video.uri;
              return SizedBox(
                width: width,
                child: Semantics(
                  button: true,
                  selected: active,
                  child: Material(
                    color: CinemaPalette.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: CinemaPalette.gold
                              .withValues(alpha: active ? 0.8 : 0.18)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() => _selected = video),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  CinemaPalette.wine,
                                  CinemaPalette.surface
                                ],
                              )),
                              child: Icon(
                                  active
                                      ? Icons.play_circle_fill
                                      : Icons.play_circle_outline,
                                  color: CinemaPalette.gold,
                                  size: 44),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                        height: nameHeight,
                                        child: Text(video.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: CinemaPalette.ivory,
                                                fontSize: 14,
                                                height: 1.3,
                                                fontWeight: FontWeight.w600))),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                        height: subtitleHeight,
                                        child: Text(
                                            '${video.type} \u00b7 ${video.site}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: CinemaPalette.muted,
                                                fontSize: 12,
                                                height: 1.3))),
                                  ]),
                            ),
                          ]),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    ]);
  }
}
