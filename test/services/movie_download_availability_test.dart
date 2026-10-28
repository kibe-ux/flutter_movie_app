import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/utils/movie_download_availability.dart';

void main() {
  final today = DateTime(2026, 10, 20, 15);

  test('future releases are blocked, including tomorrow in the same year', () {
    expect(isFutureMovieRelease('2027-01-01', now: today), isTrue);
    expect(isFutureMovieRelease('2026-10-21', now: today), isTrue);
    expect(isFutureMovieRelease('2026-10-20', now: today), isFalse);
    expect(isFutureMovieRelease('2022-03-01', now: today), isFalse);
  });

  test('unknown dates do not invent an upcoming release status', () {
    for (final value in [null, '', 'unknown', 2027]) {
      expect(isFutureMovieRelease(value, now: today), isFalse);
    }
  });

  test('only recent valid links can be reused from the details page', () {
    Map<String, dynamic> metadata(DateTime fetchedAt) => {
          'downloadUrl': 'https://example.com/movie',
          'downloadUrlFetchedAt': fetchedAt.toUtc().toIso8601String(),
        };
    expect(hasRecentMovieDownloadLink(metadata(today), now: today), isTrue);
    expect(
        hasRecentMovieDownloadLink(
            metadata(today.subtract(const Duration(seconds: 59))),
            now: today),
        isTrue);
    expect(
        hasRecentMovieDownloadLink(
            metadata(today.subtract(const Duration(minutes: 1))),
            now: today),
        isFalse);
    expect(
        hasRecentMovieDownloadLink(
            metadata(today.add(const Duration(seconds: 1))),
            now: today),
        isFalse);
    expect(
        hasRecentMovieDownloadLink({'downloadUrl': 'https://example.com/movie'},
            now: today),
        isFalse);
    expect(
        hasRecentMovieDownloadLink(
            {'downloadUrlFetchedAt': today.toIso8601String()},
            now: today),
        isFalse);
  });

  test('only an absolute HTTP file link enables the download control', () {
    for (final value in [
      null,
      '',
      '/movie.mp4',
      'javascript:alert(1)',
      'magnet:?xt=urn:btih:test',
      'https://'
    ]) {
      expect(hasMovieDownloadLink({'downloadUrl': value}), isFalse);
    }
    expect(hasMovieDownloadLink(null), isFalse);
    expect(
        hasMovieDownloadLink(
            {'downloadUrl': ' https://example.com/movie?token=test '}),
        isTrue);
    expect(
        hasMovieDownloadLink(
            {'downloadUrl': 'http://192.168.137.1:3000/movie'}),
        isTrue);
  });

  test('isMovieReleased and filterReleasedMovies filter out upcoming releases',
      () {
    expect(isMovieReleased('2027-01-01', now: today), isFalse);
    expect(isMovieReleased('2026-10-20', now: today), isTrue);

    final movies = [
      {'id': 1, 'title': 'Released Movie', 'release_date': '2025-05-10'},
      {'id': 2, 'title': 'Upcoming Movie', 'release_date': '2027-12-25'},
      {'id': 3, 'title': 'Released TV', 'first_air_date': '2024-01-01'},
      {'id': 4, 'title': 'Upcoming TV', 'first_air_date': '2028-06-01'},
    ];

    final filtered = filterReleasedMovies(movies, now: today);
    expect(filtered.map((m) => m['id']).toList(), [1, 3]);
  });
}
