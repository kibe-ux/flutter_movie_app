import 'tmdb_api.dart';
import 'dart:convert';

/// Movie metadata served through the shared backend cache.
class MediaApiService {
  static Future<Map<String, dynamic>> fetchWatchProviders(int movieId,
      {String mediaType = 'movie'}) async {
    final uri = TmdbApi.uri('$mediaType/$movieId/watch/providers');
    final response =
        await TmdbApi.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError(
          'Movie availability request failed (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['results'] is! Map) {
      throw const FormatException('Invalid movie availability response.');
    }
    return (data['results'] as Map).cast<String, dynamic>();
  }

  /// Returns a playable trailer URL (usually a YouTube link) for the
  /// given movie ID.  If the request fails or no trailer is found
  /// the future completes with null.
  static Future<String?> fetchTrailerUrl(int movieId,
      {String mediaType = 'movie'}) async {
    final url = TmdbApi.uri('$mediaType/$movieId/videos');

    final response =
        await TmdbApi.get(url).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      // could log the error here
      return null;
    }

    final data = json.decode(response.body);
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final trailer = results.firstWhere(
      (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
      orElse: () => null,
    );
    if (trailer != null) {
      return 'https://www.youtube.com/watch?v=${trailer['key']}';
    }
    return null;
  }

  /// Fetches detailed movie information from TMDB for the given movie ID.
  /// Returns null if the request fails or movie is not found.
  static Future<Map<String, dynamic>?> fetchMovieDetails(int movieId) async {
    final url = TmdbApi.uri('movie/$movieId');

    try {
      final response =
          await TmdbApi.get(url).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      return data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// (Optional) stub left in place; you can repurpose it later when
  /// the friend API becomes available.
  static Future<String?> fetchDownloadUrl(int movieId) async {
    // ignore: todo
    // TODO: implement once you have a download endpoint
    return null;
  }
}
