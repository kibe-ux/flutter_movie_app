import '../../services/tmdb_api.dart';
import 'dart:convert';

class MovieApiService {
  const MovieApiService();

  // Fetch cast
  Future<List<Map<String, dynamic>>> fetchCast(int movieId) async {
    final response = await TmdbApi.get(TmdbApi.uri('movie/$movieId/credits'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['cast'] ?? []);
    }
    return [];
  }

  // Fetch similar movies
  Future<List<Map<String, dynamic>>> fetchSimilarMovies(int movieId) async {
    final response = await TmdbApi.get(TmdbApi.uri('movie/$movieId/similar'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    return [];
  }

  // Fetch trailers
  Future<List<Map<String, dynamic>>> fetchTrailers(int movieId) async {
    final response = await TmdbApi.get(TmdbApi.uri('movie/$movieId/videos'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    return [];
  }

  // Placeholder for download link
  Future<String?> getDownloadLink(int movieId) async {
    // Replace this with your real API call that returns a downloadable URL
    return null;
  }
}
