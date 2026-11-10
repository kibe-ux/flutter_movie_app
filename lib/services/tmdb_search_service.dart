import 'dart:convert';
import 'catalogue_page_cache.dart';
import 'tmdb_api.dart';

/// Browsing never needs the paid source provider.
class TmdbSearchService {
  static final _cache = CataloguePageCache();

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String> params = const {}]) async {
    final uri = TmdbApi.uri(path, {'language': 'en-US', ...params});
    final body = await _cache.get(uri, () async {
      final response = await TmdbApi.get(uri);
      if (response.statusCode != 200) {
        throw StateError('Movie information is unavailable.');
      }
      return response.body;
    });
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final pages = await Future.wait([
      for (final type in ['movie', 'tv'])
        _get('search/$type', {'query': query.trim(), 'page': '1'})
    ]);
    return [
      for (var i = 0; i < pages.length; i++)
        for (final row in pages[i]['results'] as List)
          {
            ...Map<String, dynamic>.from(row as Map),
            'media_type': i == 0 ? 'movie' : 'tv'
          }
    ];
  }

  Future<List<Map<String, dynamic>>> genres() async {
    final pages =
        await Future.wait([_get('genre/movie/list'), _get('genre/tv/list')]);
    return {
      for (final page in pages)
        for (final genre in page['genres'] as List)
          genre['id']: Map<String, dynamic>.from(genre as Map)
    }.values.toList();
  }

  void dispose() {}
}
