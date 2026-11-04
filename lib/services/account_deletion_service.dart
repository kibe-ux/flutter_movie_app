import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AccountDeletionService {
  AccountDeletionService({http.Client? client, String? baseUrl})
      : _client = client,
        _baseUrl = baseUrl;
  final http.Client? _client;
  final String? _baseUrl;

  /// Returns true only when cleanup has completed, false for a durable request.
  Future<bool> request(User user) async {
    var base = (_baseUrl ??
        (dotenv.isInitialized
            ? dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL']
            : null) ??
        '');
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final uri = Uri.tryParse('$base/api/account');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError(
          'Account deletion is unavailable. Please try again later.');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final client = _client ?? http.Client();
    try {
      final response = await client.delete(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 60));
      if (response.statusCode == 401) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw StateError(
            'Could not request account deletion. Please try again.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!['complete', 'pending'].contains(data['status'])) {
        throw StateError(
            'Could not confirm the deletion request. Please retry.');
      }
      return data['status'] == 'complete';
    } finally {
      if (_client == null) client.close();
    }
  }
}
