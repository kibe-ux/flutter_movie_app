import 'dart:convert';
import 'package:http/http.dart' as http;

class MediaApiService {
  // 🔒 Replace these with your friend's API details
  static const String _baseUrl = 'https://YOUR_API_BASE_URL';
  static const String _apiKey = 'YOUR_API_KEY';

  /// Fetch Trailer URL
  static Future<String?> fetchTrailerUrl(int movieId) async {
    final url = Uri.parse('$_baseUrl/trailer/$movieId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load trailer');
    }

    final data = json.decode(response.body);

    // Expected response: { "trailer_url": "https://..." }
    return data['trailer_url'];
  }

  /// Fetch Download URL
  static Future<String?> fetchDownloadUrl(int movieId) async {
    final url = Uri.parse('$_baseUrl/download/$movieId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load download');
    }

    final data = json.decode(response.body);

    // Expected response: { "download_url": "https://..." }
    return data['download_url'];
  }
}
