import 'films365_models.dart';

extension Films365ItemAdapter on Films365Item {
  Map<String, dynamic>? toMovieHubItem() {
    final contentType = type?.toLowerCase();
    final numericId = tmdbId;
    if (id.trim().isEmpty ||
        numericId == null ||
        numericId < 1 ||
        (contentType != 'movie' && contentType != 'tv')) {
      return null;
    }

    final poster = posterUrl?.trim();
    return {
      'id': numericId,
      'films365_id': id.trim(),
      'content_key': '$contentType:$numericId',
      'media_type': contentType,
      'title': title,
      if (contentType == 'tv') 'name': title,
      'poster_url': poster,
      'poster_path': _tmdbImagePath(poster),
      'release_date': contentType == 'movie' ? date : null,
      'first_air_date': contentType == 'tv' ? date : null,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'popularity': popularity,
      'genres': List<String>.unmodifiable(genres),
      'data_source': 'films365',
    };
  }
}

String? _tmdbImagePath(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host != 'image.tmdb.org') return null;
  final segments = uri.pathSegments;
  if (segments.length < 4 || segments[0] != 't' || segments[1] != 'p') {
    return null;
  }
  return '/${segments.skip(3).join('/')}';
}
