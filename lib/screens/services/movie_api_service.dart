import 'dart:convert';
import 'package:http/http.dart' as http;

class MovieApiService {
  final String apiKey;
  final String baseUrl;

  MovieApiService({required this.apiKey, required this.baseUrl});

  Future<List<Map<String, dynamic>>> fetchCast(int movieId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['cast'] ?? []);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchSimilarMovies(int movieId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/movie/$movieId/similar?api_key=$apiKey'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchTrailers(int movieId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/movie/$movieId/videos?api_key=$apiKey'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    }
    return [];
  }

  Future<String?> getDownloadLink(int movieId) async {
    return null;
  }
}
