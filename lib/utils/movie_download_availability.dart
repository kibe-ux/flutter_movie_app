/// Digital window: theatrical releases typically require ~60 days before
/// appearing on digital/streaming services with verified file downloads.
const Duration digitalReleaseWindow = Duration(days: 60);

bool isFutureMovieRelease(Object? releaseDate, {DateTime? now, bool isDigitalBuffer = false}) {
  if (releaseDate is! String) return false;
  final release = DateTime.tryParse(releaseDate);
  if (release == null) return false;
  final today = now ?? DateTime.now();
  final threshold = isDigitalBuffer ? today.subtract(digitalReleaseWindow) : today;
  return DateTime(release.year, release.month, release.day)
      .isAfter(DateTime(threshold.year, threshold.month, threshold.day));
}

bool hasMovieDownloadLink(Map<String, dynamic>? metadata) {
  final value = metadata?['downloadUrl'];
  if (value is! String) return false;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

/// Reuse a just-fetched link during the same details-page interaction.
/// Older or failed downloads must resolve a fresh provider URL.
bool hasRecentMovieDownloadLink(Map<String, dynamic>? metadata,
    {DateTime? now}) {
  if (!hasMovieDownloadLink(metadata)) return false;
  final fetchedAt = metadata?['downloadUrlFetchedAt'];
  if (fetchedAt is! String) return false;
  final timestamp = DateTime.tryParse(fetchedAt);
  if (timestamp == null) return false;
  final age = (now ?? DateTime.now()).difference(timestamp);
  return !age.isNegative && age < const Duration(minutes: 1);
}

/// Returns true if the movie has already been released (not in the future).
bool isMovieReleased(Object? releaseDate, {DateTime? now}) {
  return !isFutureMovieRelease(releaseDate, now: now);
}

/// Filters a list of movie objects to exclude unreleased / future releases.
/// For movies, applies the 60-day digital release buffer so titles shown in feeds
/// actually have digital files available in the provider catalogue.
List<Map<String, dynamic>> filterReleasedMovies(
  Iterable<dynamic>? movies, {
  DateTime? now,
  bool requireDigitalRelease = true,
}) {
  if (movies == null) return <Map<String, dynamic>>[];
  return movies
      .whereType<Map<String, dynamic>>()
      .where((m) {
        final isTv = m['media_type'] == 'tv' || m['first_air_date'] != null;
        final releaseDate = m['release_date'] ?? m['first_air_date'];
        // TV episodes stream right after airing; movies require digital release window
        final applyBuffer = requireDigitalRelease && !isTv;
        return !isFutureMovieRelease(
          releaseDate,
          now: now,
          isDigitalBuffer: applyBuffer,
        );
      })
      .toList();
}
