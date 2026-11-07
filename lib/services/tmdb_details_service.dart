import 'tmdb_api.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches rich movie/TV metadata through the shared backend proxy. The map
/// uses the normalized keys expected by the details screen:
///
/// - runtime, voteAverage, voteCount
/// - mpaRating, imdbId
/// - genres         → List<String>
/// - spokenLanguages → List<String>
/// - productionCompanies, productionCountries → List<String>
/// - releaseDate, firstAirDate
/// - synopsis
/// - cast           → List<{name, character, profileUrl}>
/// - crew           → List<{name, job, profileUrl}>
/// - videos         → List<{key, site, type, name, official}>
/// - watchProviders → {results: {<country>: {...}}}
class TmdbDetailsService {
  TmdbDetailsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _imageBase = 'https://image.tmdb.org/t/p/w185';

  static final _sharedCache = <String, ({DateTime fetchedAt, Map<String, dynamic> data})>{};
  final _cache = _sharedCache;
  static const _ttl = Duration(minutes: 30);

  void dispose() => _client.close();

  Future<Map<String, dynamic>?> fetchDetails({
    required int tmdbId,
    required String mediaType, // 'movie' or 'tv'
    bool refresh = false,
  }) async {
    final key = '${mediaType}_$tmdbId';
    if (!refresh) {
      final cached = _cache[key];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _ttl) {
        return cached.data;
      }
    }

    try {
      final append = mediaType == 'movie'
          ? 'credits,videos,watch/providers,release_dates,external_ids'
          : 'credits,videos,watch/providers,content_ratings,external_ids';

      final uri = TmdbApi.uri('$mediaType/$tmdbId', {
        'language': 'en-US',
        'append_to_response': append,
      });

      final response = await TmdbApi.get(uri, client: _client)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;

      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final data = _normalize(raw, mediaType);
      _cache[key] = (fetchedAt: DateTime.now(), data: data);
      return data;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> raw, String mediaType) {
    // --- basic ---
    final runtime = mediaType == 'movie'
        ? raw['runtime']
        : _tvRuntime(raw['episode_run_time']);
    final voteAverage = raw['vote_average'];
    final voteCount = raw['vote_count'];
    final synopsis = raw['overview'];
    final releaseDate = raw['release_date'] ?? raw['first_air_date'];
    final firstAirDate = raw['first_air_date'];
    final imdbId = (raw['external_ids'] as Map?)?['imdb_id'];

    // --- MPA / content rating ---
    final mpaRating = mediaType == 'movie' ? _movieRating(raw) : _tvRating(raw);

    // --- genres ---
    final genres = [
      for (final g in raw['genres'] as List? ?? [])
        if (g is Map && g['name'] is String) g['name'] as String,
    ];

    // --- spoken languages ---
    final spokenLanguages = [
      for (final l in raw['spoken_languages'] as List? ?? [])
        if (l is Map) (l['english_name'] ?? l['name'])?.toString() ?? '',
    ].where((s) => s.isNotEmpty).toList();

    // --- production companies ---
    final productionCompanies = [
      for (final c in raw['production_companies'] as List? ?? [])
        if (c is Map && c['name'] is String) c['name'] as String,
    ];

    // --- production countries ---
    final productionCountries = [
      for (final c in raw['production_countries'] as List? ?? [])
        if (c is Map && c['name'] is String) c['name'] as String,
    ];

    // --- cast (top 20) ---
    final creditsRaw = raw['credits'] as Map?;
    final cast = [
      for (final p in (creditsRaw?['cast'] as List? ?? []).take(20))
        if (p is Map)
          {
            'name': p['name'],
            'character': p['character'],
            'profileUrl': p['profile_path'] is String
                ? '$_imageBase${p['profile_path']}'
                : null,
          }
    ];

    // --- crew (directors + top writers, deduped, max 20) ---
    final crewRaw = (creditsRaw?['crew'] as List? ?? []);
    final crewSeen = <String>{};
    final crew = [
      for (final p in crewRaw)
        if (p is Map &&
            p['name'] is String &&
            (p['job'] == 'Director' ||
                p['job'] == 'Screenplay' ||
                p['job'] == 'Writer' ||
                p['job'] == 'Story' ||
                p['job'] == 'Producer') &&
            crewSeen.add('${p['name']}|${p['job']}'))
          {
            'name': p['name'],
            'job': p['job'],
            'profileUrl': p['profile_path'] is String
                ? '$_imageBase${p['profile_path']}'
                : null,
          }
    ].take(20).toList();

    // --- videos ---
    final videos = [
      for (final v in (raw['videos']?['results'] as List? ?? []))
        if (v is Map)
          {
            'key': v['key'],
            'site': v['site'],
            'type': v['type'],
            'name': v['name'],
            'official': v['official'],
          }
    ];

    // --- watch providers ---
    final watchProviders = raw['watch/providers'];

    return {
      'runtime': runtime,
      'voteAverage': voteAverage,
      'voteCount': voteCount,
      'synopsis': synopsis,
      'releaseDate': releaseDate,
      'firstAirDate': firstAirDate,
      'imdbId': imdbId,
      'mpaRating': mpaRating,
      'genres': genres,
      'spokenLanguages': spokenLanguages,
      'productionCompanies': productionCompanies,
      'productionCountries': productionCountries,
      'casts': cast,
      'crew': crew,
      'videos': {'results': videos},
      'watchProviders': watchProviders,
    };
  }

  static num? _tvRuntime(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first as num?;
    return null;
  }

  static String _movieRating(Map<String, dynamic> raw) {
    final releaseDates = raw['release_dates']?['results'];
    if (releaseDates is! List) return '';
    // prefer US, then first available
    Map? usEntry;
    for (final country in releaseDates) {
      if (country is Map && country['iso_3166_1'] == 'US') {
        usEntry = country;
        break;
      }
    }
    final entries =
        usEntry ?? (releaseDates.isNotEmpty ? releaseDates.first : null);
    if (entries is! Map) return '';
    for (final release in entries['release_dates'] as List? ?? []) {
      if (release is Map) {
        final cert = release['certification']?.toString().trim() ?? '';
        if (cert.isNotEmpty) return cert;
      }
    }
    return '';
  }

  static String _tvRating(Map<String, dynamic> raw) {
    final ratings = raw['content_ratings']?['results'];
    if (ratings is! List) return '';
    for (final r in ratings) {
      if (r is Map && r['iso_3166_1'] == 'US') {
        return r['rating']?.toString().trim() ?? '';
      }
    }
    return '';
  }
}
