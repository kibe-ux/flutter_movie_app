import 'dart:convert';
import 'package:http/http.dart' as http;

class MovieApiService {
  final String apiKey;
  final String baseUrl;

  MovieApiService({required this.apiKey, required this.baseUrl});

  // Fetch cast
  Future<List<Map<String, dynamic>>> fetchCast(int movieId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['cast'] ?? []);
    }
    return [];
  }

  // Fetch similar movies
  Future<List<Map<String, dynamic>>> fetchSimilarMovies(int movieId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/movie/$movieId/similar?api_key=$apiKey'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    return [];
  }

  // Fetch trailers
  Future<List<Map<String, dynamic>>> fetchTrailers(int movieId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/movie/$movieId/videos?api_key=$apiKey'));
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
