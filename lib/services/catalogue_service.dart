import 'tmdb_api.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../utils/movie_download_availability.dart';
import 'catalogue_page_cache.dart';

class CatalogueLoadException implements Exception {
  const CatalogueLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CataloguePage {
  const CataloguePage({required this.items, required this.hasMore});

  final List<Map<String, dynamic>> items;
  final bool hasMore;
}

class CatalogueService {
  const CatalogueService({
    this.timeout = const Duration(seconds: 20),
    CataloguePageCache? cache,
  }) : _cache = cache;

  final Duration timeout;
  final CataloguePageCache? _cache;
  static CataloguePageCache _sharedCache = CataloguePageCache();

  @visibleForTesting
  static void resetCacheForTesting() {
    _sharedCache = CataloguePageCache(persist: false);
  }

  Future<CataloguePage> fetchPage(Uri uri, {bool refresh = false}) async {
    try {
      final body = await (_cache ?? _sharedCache)
          .get(uri, () => _request(uri), refresh: refresh);
      final data = _decode(body);
      final results = data['results'] as List;
      final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
      final totalPages = data['total_pages'];
      return CataloguePage(
        items: filterReleasedMovies(results)
            .where((item) => item['id'] is int)
            .toList(),
        hasMore:
            results.isNotEmpty && (totalPages is! num || page < totalPages),
      );
    } on TimeoutException {
      throw const CatalogueLoadException(
          'The connection took too long. Please try again.');
    } on http.ClientException {
      throw const CatalogueLoadException(
          'Check your connection and try again.');
    } on FormatException {
      throw const CatalogueLoadException(
          'We could not read the movie list. Please try again.');
    }
  }

  Map<String, dynamic> _decode(String body) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> || data['results'] is! List) {
      throw const FormatException('Invalid movie list');
    }
    return data;
  }

  Future<String> _request(Uri uri) async {
    final response = await TmdbApi.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw const CatalogueLoadException(
          'Movies are temporarily unavailable. Please try again.');
    }
    _decode(response.body);
    return response.body;
  }
}
