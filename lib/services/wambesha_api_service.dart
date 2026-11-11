import 'backend_url.dart';
import 'http_diagnostics.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class WambeshaApiService {
  WambeshaApiService({
    http.Client? client,
    String Function()? baseUrlProvider,
    Future<String?> Function(bool forceRefresh)? tokenProvider,
  })  : _client = client ?? http.Client(),
        _baseUrlProvider = baseUrlProvider,
        _tokenProvider = tokenProvider;

  final http.Client _client;
  final String Function()? _baseUrlProvider;
  final Future<String?> Function(bool)? _tokenProvider;
  final _sourceCache = <String, WambeshaSources>{};
  final _pendingSources = <String, Future<WambeshaSources>>{};
  final _titleCache = <String, ({String id, DateTime expiresAt})>{};
  final _pendingTitles = <String, Future<String>>{};
  static final _titleReference = RegExp(
      r'^(?:(?:mv|sr|sn|ep)_[A-Za-z0-9]{1,40}|imdb:tt[0-9]{1,20}|tvdb:[0-9]{1,20}|tmdb:(?:movie|tv):[0-9]{1,20})$');

  void dispose() => _client.close();

  Future<String?> _token(bool refresh) async => _tokenProvider != null
      ? _tokenProvider(refresh)
      : FirebaseAuth.instance.currentUser?.getIdToken(refresh);

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String> parameters = const {}]) async {
    const definedUrl = String.fromEnvironment('MOVIE_DOWNLOAD_API_BASE_URL');
    final base = (_baseUrlProvider?.call() ??
            (dotenv.isInitialized
                ? dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL']
                : null) ??
            (definedUrl.isNotEmpty
                ? definedUrl
                : (kDebugMode ? 'http://127.0.0.1:3000' : '')))
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) throw const WambeshaRequestException(503);
    final uri = Uri.parse('${validateBackendUrl(base)}/api/wambesha/$path')
        .replace(queryParameters: parameters.isEmpty ? null : parameters);
    var token = await _token(false);
    if (token == null || token.trim().isEmpty) {
      throw const WambeshaRequestException(401);
    }
    Future<http.Response> send() async {
      final response = await _client.get(uri, headers: {
        'Authorization': 'Bearer $token'
      }).timeout(const Duration(seconds: 20));
      logHttpDiagnostic(
        endpoint:
            'wambesha/${path.replaceAll(RegExp(r'titles/[^/]+'), 'titles/:id')}',
        status: response.statusCode,
        headers: response.headers,
      );
      return response;
    }

    var response = await send();
    if (response.statusCode == 401 &&
        response.headers['x-moviehub-response-source'] == 'firebase-auth') {
      token = await _token(true);
      if (token != null && token.trim().isNotEmpty) response = await send();
    }
    if (response.statusCode != 200) {
      throw WambeshaRequestException(response.statusCode);
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> genres() async {
    final body = await _get('genres');
    return List<Map<String, dynamic>>.from(body['items'] as List);
  }

  Future<String> resolveTitle(
      {required int tmdbId,
      required String type,
      String? titleRef,
      String? title,
      String? releaseDate}) async {
    final prefix = type == 'movie' ? 'mv_' : 'sr_';
    if (titleRef != null &&
        titleRef.startsWith(prefix) &&
        RegExp(r'^(mv|sr)_[A-Za-z0-9]{1,40}$').hasMatch(titleRef)) {
      return titleRef;
    }
    final token = await _token(false);
    if (token == null || token.trim().isEmpty) {
      throw const WambeshaRequestException(401);
    }
    final scope =
        '${_baseUrlProvider?.call() ?? ''}|$token|$type|$tmdbId|${title ?? ''}|${releaseDate ?? ''}';
    final cached = _titleCache[scope];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.id;
    }
    final pending = _pendingTitles[scope];
    if (pending != null) return pending;
    final future = () async {
      final id = await _resolveTitle(
          tmdbId: tmdbId, type: type, title: title, releaseDate: releaseDate);
      if (_titleCache.length >= 64) _titleCache.remove(_titleCache.keys.first);
      _titleCache[scope] = (
        id: id,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      return id;
    }();
    _pendingTitles[scope] = future;
    try {
      return await future;
    } finally {
      _pendingTitles.remove(scope);
    }
  }

  Future<String> _resolveTitle(
      {required int tmdbId,
      required String type,
      String? title,
      String? releaseDate}) async {
    final prefix = type == 'movie' ? 'mv_' : 'sr_';
    final recordType = type == 'movie' ? 'movie' : 'series';
    final validId = RegExp(r'^(mv|sr)_[A-Za-z0-9]{1,40}$');
    try {
      final record = await _get('lookup', {
        'tmdb_id': '$tmdbId',
        'type': recordType,
      });
      final id = record['id'];
      if (id is String &&
          validId.hasMatch(id) &&
          id.startsWith(prefix) &&
          record['type'] == recordType) {
        return id;
      }
    } on WambeshaRequestException catch (error) {
      // Authentication, ambiguity, quota and server failures must remain visible.
      if (error.statusCode != 404 || title == null || title.trim().length < 2) {
        rethrow;
      }
    }
    if (title == null || title.trim().length < 2) {
      throw const WambeshaSourceUnavailable(
          'This title could not be matched in the source catalogue.');
    }
    final searchBody =
        await _get('search', {'q': title.trim(), 'language': 'en'});
    final cards = searchBody['titles']?['items'] as List? ?? [];
    final ids = <String>{
      for (final card in cards)
        if (card is Map &&
            card['type'] == recordType &&
            card['id'] is String &&
            validId.hasMatch(card['id']) &&
            (card['id'] as String).startsWith(prefix))
          card['id'] as String,
    }.take(100).toList();
    if (ids.isEmpty) {
      throw const WambeshaSourceUnavailable(
          'This title could not be matched in the source catalogue.');
    }
    // Batch full records: search cards may omit external IDs and release dates.
    final body = await _get('titles', {'ids': ids.join(','), 'language': 'en'});
    final exactIds = <String>{};
    final titleMatches = <String>{};
    final year = DateTime.tryParse(releaseDate ?? '')?.year;
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r"[\s:.,!?_'’\-–—]+"), ' ')
        .trim();
    for (final record in body['items'] as List? ?? []) {
      if (record is! Map ||
          record['type'] != recordType ||
          !ids.contains(record['id'])) {
        continue;
      }
      final id = record['id'] as String;
      final external = record['external_ids'];
      final linkedId = external is Map ? external['tmdb_id'] : null;
      if (linkedId != null && '$linkedId'.isNotEmpty) {
        if (int.tryParse('$linkedId') == tmdbId) exactIds.add(id);
        continue;
      }
      final recordYear = int.tryParse('${record['year']}') ??
          DateTime.tryParse(
                  '${record[type == 'movie' ? 'release_date' : 'first_air_date']}')
              ?.year;
      final names =
          [record['title'], record['original_title']].whereType<String>();
      if (year != null &&
          recordYear == year &&
          names.any((name) => normalize(name) == normalize(title))) {
        titleMatches.add(id);
      }
    }
    final matches = exactIds.isNotEmpty ? exactIds : titleMatches;
    if (matches.length == 1) return matches.single;
    throw WambeshaSourceUnavailable(matches.length > 1
        ? 'More than one catalogue title matches this title and year. Please report this movie.'
        : 'This title could not be matched in the source catalogue.');
  }

  Future<WambeshaSources> movieSources(
      {required int tmdbId,
      String? titleRef,
      String? title,
      String? releaseDate,
      bool refresh = false}) async {
    final id = await resolveTitle(
        tmdbId: tmdbId,
        type: 'movie',
        titleRef: titleRef,
        title: title,
        releaseDate: releaseDate);
    return sources(id, refresh: refresh);
  }

  Future<WambeshaSources> episodeSources(
      {required int seriesTmdbId,
      required int season,
      required int episode,
      String? seriesRef,
      String? seriesTitle,
      String? releaseDate,
      bool refresh = false}) async {
    final id = await resolveTitle(
        tmdbId: seriesTmdbId,
        type: 'tv',
        titleRef: seriesRef,
        title: seriesTitle,
        releaseDate: releaseDate);
    String? cursor;
    final visited = <String>{};
    for (var page = 0; page < 20; page++) {
      final body = await _get('titles/$id/episodes', {
        'season': '$season',
        'limit': '50',
        if (cursor != null) 'cursor': cursor,
      });
      for (final item in body['items'] as List? ?? []) {
        if (item['season_number'] == season &&
            item['episode_number'] == episode &&
            item['id'] is String &&
            (item['id'] as String).startsWith('ep_')) {
          return sources(item['id'] as String, refresh: refresh);
        }
      }
      cursor = body['next_cursor'] as String?;
      if (cursor == null || !visited.add(cursor)) break;
    }
    throw const WambeshaSourceUnavailable(
        'This episode could not be matched in the source catalogue.');
  }

  /// Only called on explicit play/download actions. Concurrent actions share
  /// a verification; cached answers expire before any signed URL does.
  Future<WambeshaSources> sources(String titleRef,
      {bool refresh = false}) async {
    if (!_titleReference.hasMatch(titleRef)) {
      throw ArgumentError('Invalid Wambesha title reference.');
    }
    final token = await _token(false);
    if (token == null || token.trim().isEmpty) {
      throw const WambeshaRequestException(401);
    }
    final scope = '${_baseUrlProvider?.call() ?? ''}|$token|$titleRef';
    final cached = _sourceCache[scope];
    if (!refresh && cached != null && cached.isReusable) return cached;
    final pending = _pendingSources[scope];
    if (pending != null) return pending;
    final future = () async {
      final body = await _get('titles/$titleRef/sources');
      final result = WambeshaSources.fromJson(body);
      if (_sourceCache.length >= 32) {
        _sourceCache.remove(_sourceCache.keys.first);
      }
      _sourceCache[scope] = result;
      return result;
    }();
    _pendingSources[scope] = future;
    try {
      return await future;
    } finally {
      _pendingSources.remove(scope);
    }
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.trim().length < 2) return [];
    final body = await _get('search', {'q': query.trim(), 'language': 'en'});
    final cards =
        List<Map<String, dynamic>>.from(body['titles']['items'] as List);
    final ids = cards
        .where((card) => card['type'] == 'movie' || card['type'] == 'series')
        .map((card) => card['id'] as String)
        .take(100)
        .toList();
    if (ids.isEmpty) return [];
    final records =
        await _get('titles', {'ids': ids.join(','), 'language': 'en'});
    final byId = {
      for (final record
          in List<Map<String, dynamic>>.from(records['items'] as List))
        record['id']: record,
    };
    final results = <Map<String, dynamic>>[];
    // Search order is authoritative; batch records may omit withdrawn titles.
    for (final id in ids) {
      final record = byId[id];
      if (record == null) continue;
      final item = normalizeTitle(record);
      if (item != null) results.add(item);
    }
    return results;
  }

  /// Fetches verified, available titles directly from Wambesha's /discover endpoint.
  Future<List<Map<String, dynamic>>> discover({
    String type = 'movie',
    String? genre,
    String? year,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final body = await _get('discover', {
        'type': type,
        'limit': '$limit',
        if (genre != null && genre.isNotEmpty) 'genre': genre,
        if (year != null && year.isNotEmpty) 'year': year,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      });
      final rawItems =
          (body['items'] ?? body['titles']?['items']) as List? ?? [];
      final ids = rawItems
          .whereType<Map>()
          .map((card) => card['id'] as String?)
          .whereType<String>()
          .take(limit)
          .toList();
      if (ids.isEmpty) return [];
      final records =
          await _get('titles', {'ids': ids.join(','), 'language': 'en'});
      final byId = {
        for (final record
            in List<Map<String, dynamic>>.from(records['items'] as List? ?? []))
          record['id']: record,
      };
      final results = <Map<String, dynamic>>[];
      for (final id in ids) {
        final record = byId[id];
        if (record == null) continue;
        final item = normalizeTitle(record);
        if (item != null) results.add(item);
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Existing details, saved lists and downloads identify titles by TMDB ID.
  /// Never substitute a Wambesha ID or a made-up numeric ID for that identity.
  static Map<String, dynamic>? normalizeTitle(Map<String, dynamic> record) {
    final type = record['type'];
    if (type != 'movie' && type != 'series') return null;
    final external = record['external_ids'];
    final id = external is Map ? int.tryParse('${external['tmdb_id']}') : null;
    if (id == null || id < 1) return null;
    final isMovie = type == 'movie';
    return {
      'id': id,
      'wambesha_id': record['id'],
      'media_type': isMovie ? 'movie' : 'tv',
      isMovie ? 'title' : 'name': record['title'],
      isMovie ? 'original_title' : 'original_name': record['original_title'],
      'overview': record['synopsis'],
      'year': record['year'],
      'release_date': record['release_date'],
      'first_air_date': record['first_air_date'],
      'catalogue_status': record['status'],
      'poster_url': record['poster']?['url'],
      'backdrop_url': record['backdrop']?['url'],
      'genre_ids': [
        for (final genre in record['genres'] as List? ?? []) genre['id'],
      ],
    };
  }
}

class WambeshaSources {
  WambeshaSources(
      {required this.sources,
      required this.unverified,
      this.id,
      this.subtitles = const [],
      this.trailers = const [],
      this.verificationSpent})
      : fetchedAt = DateTime.now();
  factory WambeshaSources.fromJson(Map<String, dynamic> body) =>
      WambeshaSources(
        id: body['id'] as String?,
        sources: [
          for (final item in body['sources'] as List? ?? [])
            if (item is Map) Map<String, dynamic>.from(item)
        ],
        unverified: (body['unverified'] as num?)?.toInt() ?? 0,
        subtitles: _records(body['subtitles']),
        trailers: _records(body['trailers']),
        verificationSpent: body['verification_spent'] as bool?,
      );
  static List<Map<String, dynamic>> _records(dynamic items) => [
        for (final item in items is List ? items : const [])
          if (item is Map) Map<String, dynamic>.from(item),
      ];
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> subtitles;
  final List<Map<String, dynamic>> trailers;
  final bool? verificationSpent;
  Iterable<Map<String, dynamic>> get _allLinks =>
      [...sources, ...subtitles, ...trailers];
  List<Map<String, dynamic>> get availableSubtitles =>
      subtitles.where(_valid).toList();
  List<Map<String, dynamic>> get availableTrailers =>
      trailers.where(_valid).toList();
  final String? id;
  final int unverified;
  final DateTime fetchedAt;
  bool get isReusable =>
      DateTime.now().difference(fetchedAt) <
          (_allLinks.isEmpty
              ? const Duration(seconds: 30)
              : const Duration(minutes: 5)) &&
      _allLinks.every((source) => _valid(source));
  bool _valid(Map<String, dynamic> source) {
    final url = source['url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    final expiryValue = source['expires_at'];
    final expires =
        expiryValue is String ? DateTime.tryParse(expiryValue) : null;
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (expiryValue == null ||
            (expires != null &&
                expires
                    .isAfter(DateTime.now().add(const Duration(seconds: 30)))));
  }

  bool get hasPlayback => sources
      .any((source) => source['kind'] == 'playback_holding' && _valid(source));

  bool get hasDownload => sources
      .any((source) => source['kind'] == 'file_holding' && _valid(source));

  String requirePlaybackUrl({bool fallbackToFile = false}) {
    for (final source in sources) {
      if (source['kind'] == 'playback_holding' && _valid(source)) {
        return source['url'] as String;
      }
    }
    if (fallbackToFile) {
      for (final source in sources) {
        if (source['kind'] == 'file_holding' && _valid(source)) {
          return source['url'] as String;
        }
      }
    }
    if (hasDownload) {
      throw const WambeshaSourceUnavailable(
          'Online streaming is not available for this title. Please tap Download to save it for offline viewing.');
    }
    throw WambeshaSourceUnavailable(unverified > 0
        ? 'Wambesha could not confirm a playback source for this title. Please try again later.'
        : 'No confirmed playback source is available for this title.');
  }

  /// Returns all available download sources with human-readable quality labels.
  /// Labels are sourced from provider metadata when available, URL patterns when
  /// detectable, and a neutral 'Source N' index otherwise.
  List<Map<String, String>> get downloadQualities {
    final list = <Map<String, String>>[];
    for (final s in sources) {
      if (s['kind'] == 'file_holding' && _valid(s)) {
        final url = s['url'] as String;
        final rawQuality =
            (s['quality'] ?? s['label'] ?? s['resolution'])?.toString();
        String label;
        if (rawQuality != null && rawQuality.isNotEmpty) {
          label = rawQuality.toUpperCase();
        } else if (url.contains('1080') ||
            url.contains('FHD') ||
            url.contains('fhd')) {
          label = '1080p (Full HD)';
        } else if (url.contains('720') ||
            url.contains('hd720') ||
            url.contains('HD720')) {
          label = '720p (HD)';
        } else if (url.contains('480') ||
            url.contains('SD') ||
            url.contains('sd480')) {
          label = '480p (Data Saver)';
        } else {
          label = 'Source ${list.length + 1}';
        }
        list.add({
          'url': url,
          'label': label,
          if (s['bytes'] is int && s['bytes'] >= 0) 'bytes': '${s['bytes']}',
          if (s['locale'] is String) 'locale': s['locale'] as String,
        });
      }
    }
    return list;
  }

  /// Finds the valid download URL matching a preferred quality label or falls back to first valid
  String? urlForQuality(String? preferredLabel) {
    if (preferredLabel != null && preferredLabel.isNotEmpty) {
      for (final item in downloadQualities) {
        if (item['label'] == preferredLabel) {
          return item['url'];
        }
      }
    }
    final qualities = downloadQualities;
    if (qualities.isNotEmpty) {
      return qualities.first['url'];
    }
    try {
      return requireUrl('file_holding');
    } catch (_) {
      return null;
    }
  }

  bool isUrlExpiredOrInvalid(String url) {
    for (final s in sources) {
      if (s['url'] == url) {
        return !_valid(s);
      }
    }
    return true;
  }

  String requireUrl(String kind) {
    for (final source in sources) {
      if (source['kind'] == kind && _valid(source)) {
        return source['url'] as String;
      }
    }
    if (kind == 'playback_holding' && hasDownload) {
      throw const WambeshaSourceUnavailable(
          'Online streaming is not available for this title. Please tap Download to save it for offline viewing.');
    }
    throw WambeshaSourceUnavailable(unverified > 0
        ? 'Wambesha could not confirm a file source for this title. Please try again later.'
        : kind == 'playback_holding'
            ? 'No confirmed playback source is available for this title.'
            : 'No download is available for this title currently. Please try another title.');
  }
}

class WambeshaSourceUnavailable implements Exception {
  const WambeshaSourceUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class WambeshaRequestException implements Exception {
  const WambeshaRequestException(this.statusCode);
  final int statusCode;
  String get message => switch (statusCode) {
        401 => 'Please sign in again to use the movie service.',
        429 => 'Source check limit reached. Please try again later.',
        404 => 'This title was not found in the source catalogue.',
        409 =>
          'This title has an ambiguous catalogue identifier. Please report it.',
        503 => 'Movie service is not available yet. Please try again later.',
        502 =>
          'The movie source service could not provide download information. Please try again later.',
        408 ||
        504 =>
          'The movie source service took too long to respond. Please try again.',
        403 =>
          'The movie service denied access to this title. Please report this movie.',
        410 => 'This title is no longer available in the source catalogue.',
        _ =>
          'The movie service could not complete this request. Please try again later.',
      };
  @override
  String toString() => 'Movie search request failed ($statusCode).';
}
