import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lightweight helper for any media‑related network calls.
///
/// The class initially supported a custom friend API, but for the
/// current trailer/ download flow we simply hit TMDB directly.  The
/// key is read from the `.env` file so you can switch environments
/// without recompiling.
class MediaApiService {
  static const String _tmdbBase = 'https://api.themoviedb.org/3';

  static String get _apiKey => dotenv.env['MOVIE_API_KEY'] ?? '';

  static Future<Map<String, dynamic>> fetchWatchProviders(int movieId,
      {String mediaType = 'movie'}) async {
    if (_apiKey.isEmpty) {
      throw StateError('Movie availability is not configured.');
    }
    final uri = Uri.parse('$_tmdbBase/$mediaType/$movieId/watch/providers')
        .replace(queryParameters: {'api_key': _apiKey});
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
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
    if (_apiKey.isEmpty) return null;

    final url =
        Uri.parse('$_tmdbBase/$mediaType/$movieId/videos?api_key=$_apiKey');

    final response = await http.get(url).timeout(const Duration(seconds: 30));
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
    if (_apiKey.isEmpty) return null;

    final url = Uri.parse('$_tmdbBase/movie/$movieId?api_key=$_apiKey');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 30));
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
