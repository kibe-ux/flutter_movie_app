import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Public movie metadata goes through the backend; no provider key is bundled.
class TmdbApi {
  static Future<String>? _installation;
  static String? _installationValue;

  static String get baseUrl {
    const defined = String.fromEnvironment('MOVIE_DOWNLOAD_API_BASE_URL');
    final value = ((dotenv.isInitialized
                ? dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL']
                : null) ??
            (defined.isNotEmpty
                ? defined
                : (kDebugMode ? 'http://127.0.0.1:3000' : '')))
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !['https', 'http'].contains(parsed.scheme) ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw StateError('The movie information backend is not configured.');
    }
    return '$value/api/catalogue/3';
  }

  static Uri uri(String path, [Map<String, String> parameters = const {}]) =>
      Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}')
          .replace(queryParameters: parameters.isEmpty ? null : parameters);

  static Future<String> _installationId() async {
    final random = Random.secure();
    final generated = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('catalogue_installation_id');
      if (saved != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(saved)) {
        return saved;
      }
      await prefs.setString('catalogue_installation_id', generated);
    } catch (_) {
      // An in-memory ID still allows browsing if device storage is unavailable.
    }
    return generated;
  }

  static Future<String?> _token(bool refresh) async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken(refresh);
    } catch (_) {
      return null;
    } // Guest browsing is supported before sign-in.
  }

  static Future<http.Response> get(
    Uri uri, {
    http.Client? client,
    Future<String?> Function(bool refresh)? tokenProvider,
  }) async {
    // Protect against accidentally reintroducing direct provider requests or
    // sending Firebase credentials to an unrelated host.
    final base = Uri.parse(baseUrl);
    if (uri.origin != base.origin ||
        !uri.path.startsWith('${base.path}/') ||
        uri.queryParameters.containsKey('api_key')) {
      throw StateError('Movie information must use the backend proxy.');
    }
    final installation =
        _installationValue ?? await (_installation ??= _installationId());
    _installationValue = installation;
    _installation = null;
    final provider = tokenProvider ?? _token;
    var token = await provider(false);
    Future<http.Response> send() {
      final headers = {
        'X-MovieHub-Installation': installation,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      return (client == null
              ? http.get(uri, headers: headers)
              : client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 25));
    }

    var response = await send();
    if (response.statusCode == 401 &&
        response.headers['x-moviehub-response-source'] == 'firebase-auth') {
      token = await provider(true);
      if (token != null && token.isNotEmpty) response = await send();
    }
    return response;
  }
}
