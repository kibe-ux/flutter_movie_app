bool isFutureMovieRelease(Object? releaseDate, {DateTime? now}) {
  if (releaseDate is! String) return false;
  final release = DateTime.tryParse(releaseDate);
  if (release == null) return false;
  final today = now ?? DateTime.now();
  return DateTime(release.year, release.month, release.day)
      .isAfter(DateTime(today.year, today.month, today.day));
}

bool hasMovieDownloadLink(Map<String, dynamic>? metadata) {
  final value = metadata?['downloadUrl'];
  if (value is! String) return false;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

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

bool isMovieReleased(Object? releaseDate, {DateTime? now}) {
  return !isFutureMovieRelease(releaseDate, now: now);
}

List<Map<String, dynamic>> filterReleasedMovies(
  Iterable<dynamic>? movies, {
  DateTime? now,
}) {
  if (movies == null) return <Map<String, dynamic>>[];
  return movies
      .whereType<Map<String, dynamic>>()
      .where((m) => !isFutureMovieRelease(
          m['release_date'] ?? m['first_air_date'],
          now: now))
      .toList();
}
