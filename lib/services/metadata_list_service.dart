import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'catalogue_page_cache.dart';
import 'tmdb_api.dart';

/// Shared, persistent metadata lists, independent of download sources.
class MetadataListService {
  static CataloguePageCache _cache = _newCache();
  static CataloguePageCache _newCache({bool persist = true}) =>
      CataloguePageCache(
          persistenceKey: 'tmdb_metadata_lists_v1', persist: persist);

  @visibleForTesting
  static void resetCacheForTesting({bool persist = false}) {
    _cache = _newCache(persist: persist);
  }

  Future<List<Map<String, dynamic>>> fetch(String path,
      {String field = 'results'}) async {
    final uri = TmdbApi.uri(path, {'language': 'en-US'});
    final body = await _cache.get(uri, () async {
      final response = await TmdbApi.get(uri);
      if (response.statusCode != 200) throw StateError('Metadata unavailable');
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = raw[field];
      if (rows is! List || rows.any((row) => row is! Map)) {
        throw const FormatException('Invalid metadata list');
      }
      return jsonEncode({'results': rows});
    });
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['results'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }
}
