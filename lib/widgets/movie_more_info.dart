import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';

import '../models/movie_more_info.dart';
import 'movie_watch_providers.dart';
import 'safe_network_image.dart';
import 'movie_trailers.dart';

class MovieMoreInfo extends StatelessWidget {
  const MovieMoreInfo(
      {super.key,
      required this.movieId,
      required this.metadata,
      required this.onRetry,
      this.mediaType = 'movie'});

  final int movieId;
  final String mediaType;
  final Future<Map<String, dynamic>?> metadata;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CinemaPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x33E6BB83)),
      ),
      child: Material(
          type: MaterialType.transparency,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline_rounded, color: CinemaPalette.gold),
              SizedBox(width: 10),
              Expanded(
                  child: Text('More info',
                      style: TextStyle(
                          color: CinemaPalette.ivory,
                          fontSize: 22,
                          fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>?>(
              future: metadata,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child:
                          LinearProgressIndicator(color: CinemaPalette.gold));
                }
                final details = snapshot.data;
                if (snapshot.hasError || details == null || details.isEmpty) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'More info could not be loaded. Please try again.',
                            style: TextStyle(color: CinemaPalette.muted)),
                        TextButton.icon(
                            onPressed: onRetry,
                            style: TextButton.styleFrom(
                                foregroundColor: CinemaPalette.gold),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ]);
                }
                final genres = movieInfoNames(details['genres']);
                final casts =
                    movieInfoRecords(details['casts'] ?? details['cast']);
                final crew = movieInfoRecords(details['crew']);
                final videos = MovieInfoVideo.featuredFromDetails(details);
                final rawProviders = details['watchProviders'];
                final rawResults =
                    rawProviders is Map ? rawProviders['results'] : null;
                final providers = rawResults is Map
                    ? Map<String, dynamic>.from(rawResults)
                    : <String, dynamic>{};
                final synopsis = details['synopsis'];
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading('Categories'),
                      if (genres.isEmpty)
                        _empty('No categories supplied.')
                      else
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          for (final genre in genres)
                            Chip(
                                label: Text(genre),
                                backgroundColor: CinemaPalette.wine,
                                labelStyle:
                                    const TextStyle(color: CinemaPalette.gold),
                                side: BorderSide.none),
                        ]),
                      if (synopsis is String && synopsis.trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _heading('Synopsis'),
                        Text(synopsis.trim(),
                            style: const TextStyle(
                                color: CinemaPalette.muted, height: 1.5)),
                      ],
                      _section('Cast', Icons.people_outline,
                          _people(context, casts, 'character')),
                      _section('Crew', Icons.movie_creation_outlined,
                          _people(context, crew, 'job')),
                      _section(
                          'Trailers & videos',
                          Icons.ondemand_video_outlined,
                          videos.isEmpty
                              ? _empty('No trailers or videos supplied.')
                              : MovieTrailers(videos: videos)),
                      _section('Additional info', Icons.article_outlined,
                          _additionalInfo(details)),
                      const SizedBox(height: 18),
                      MovieWatchProviders(
                          movieId: movieId,
                          mediaType: mediaType,
                          suppliedResults: providers),
                    ]);
              },
            ),
          ])),
    );
  }

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              color: CinemaPalette.ivory,
              fontSize: 16,
              fontWeight: FontWeight.w600)));

  Widget _empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(color: CinemaPalette.muted)));

  Widget _section(String title, IconData icon, Widget body) => Theme(
      data: ThemeData.dark().copyWith(
        dividerColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: CinemaPalette.gold,
          onPrimary: CinemaPalette.background,
          secondary: CinemaPalette.gold,
          onSecondary: CinemaPalette.background,
          surface: CinemaPalette.surface,
          onSurface: CinemaPalette.ivory,
        ),
      ),
      child: ExpansionTile(
          iconColor: CinemaPalette.gold,
          collapsedIconColor: CinemaPalette.muted,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(icon, color: CinemaPalette.gold),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [SizedBox(width: double.infinity, child: body)]));

  Widget _people(
      BuildContext context, List<Map<String, dynamic>> people, String roleKey) {
    final namedPeople = people
        .where((person) =>
            person['name'] is String &&
            (person['name'] as String).trim().isNotEmpty)
        .toList();
    if (namedPeople.isEmpty) {
      return _empty('No ${roleKey == 'job' ? 'crew' : 'cast'} supplied.');
    }
    final scaler = MediaQuery.textScalerOf(context);
    final nameHeight = scaler.scale(14) * 1.3 * 2;
    final roleHeight = scaler.scale(12) * 1.3 * 2;
    return SizedBox(
      height: 164 + 12 + nameHeight + 4 + roleHeight + 8,
      child: ListView.separated(
        key: PageStorageKey(
            roleKey == 'job' ? 'movie-crew-row' : 'movie-cast-row'),
        scrollDirection: Axis.horizontal,
        itemCount: namedPeople.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final person = namedPeople[index];
          final role = person[roleKey] is String
              ? (person[roleKey] as String).trim()
              : '';
          return SizedBox(
            width: 126,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SafeNetworkImage(
                  imageUrl: person['profileUrl'] is String
                      ? person['profileUrl'] as String
                      : null,
                  width: 126,
                  height: 164,
                  placeholderIconSize: 36,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                  height: nameHeight,
                  child: Text(
                    (person['name'] as String).trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: CinemaPalette.ivory,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600),
                  )),
              const SizedBox(height: 4),
              SizedBox(
                  height: roleHeight,
                  child: Text(
                    role,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: CinemaPalette.muted, fontSize: 12, height: 1.3),
                  )),
            ]),
          );
        },
      ),
    );
  }

  Widget _additionalInfo(Map<String, dynamic> details) {
    String text(Object? value) => value is String ? value.trim() : '';
    final runtime = details['runtime'];
    final rows = <String, String>{
      'Release date': text(details['releaseDate'] ?? details['firstAirDate'])
          .split('T')
          .first,
      if (runtime is num && runtime > 0) 'Runtime': '${runtime.toInt()} min',
      'Content rating': text(details['mpaRating']),
      'Languages': movieInfoNames(details['spokenLanguages']).join(', '),
      'Production companies':
          movieInfoNames(details['productionCompanies']).join(', '),
      'Production countries':
          movieInfoNames(details['productionCountries']).join(', '),
    }..removeWhere((key, value) => value.isEmpty);
    if (rows.isEmpty) return _empty('No additional information supplied.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in rows.entries)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.key,
                  style: const TextStyle(
                      color: CinemaPalette.muted, fontSize: 12)),
              const SizedBox(height: 3),
              Text(entry.value,
                  style: const TextStyle(color: CinemaPalette.ivory)),
            ])),
    ]);
  }
}
