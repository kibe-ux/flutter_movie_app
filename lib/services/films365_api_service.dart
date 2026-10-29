import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/films365_models.dart';
import '../utils/movie_download_availability.dart';
import 'http_diagnostics.dart';

enum Films365ContentType { all, movie, tv }

enum Films365DetailsType { movie, tv }

enum Films365SortBy { popularity, rating, date }

enum Films365SortOrder { asc, desc }

class Films365ApiService {
  Films365ApiService({
    http.Client? client,
    String Function()? apiBaseUrlProvider,
    Future<String?> Function()? idTokenProvider,
    Duration requestTimeout = const Duration(seconds: 30),
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _apiBaseUrlProvider = apiBaseUrlProvider,
        _idTokenProvider = idTokenProvider,
        _requestTimeout = requestTimeout,
        _now = now ?? DateTime.now;

  static const _debugBackendUrl = 'http://127.0.0.1:3000';
  static const _releaseBackendUrl =
      String.fromEnvironment('MOVIE_DOWNLOAD_API_BASE_URL');
  static const _films365ApiPath = '/api/mobile';
  final http.Client _client;
  final String Function()? _apiBaseUrlProvider;
  final Future<String?> Function()? _idTokenProvider;
  final Duration _requestTimeout;
  final DateTime Function() _now;
  final Map<String, String?> _uuidCache = {};
  final _infoCache =
      <String, ({DateTime fetchedAt, Map<String, dynamic> data})>{};
  final _pendingInfo = <String, Future<Map<String, dynamic>?>>{};
  static const _infoCacheLifetime = Duration(minutes: 2);
  static const _maxInfoEntries = 32;

  bool get isConfigured => _backendUrl.isNotEmpty;

  String _cacheKey(int tmdbId, String type) => '${type}_$tmdbId';

  String get _backendUrl {
    final configuredUrl = _apiBaseUrlProvider?.call() ??
        dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL'];
    final baseUrl = configuredUrl != null && configuredUrl.trim().isNotEmpty
        ? configuredUrl
        : (_releaseBackendUrl.isNotEmpty
            ? _releaseBackendUrl
            : (kDebugMode ? _debugBackendUrl : ''));
    return baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  Future<Object?> trending({
    Films365ContentType type = Films365ContentType.all,
    int page = 1,
  }) =>
      _listItems(_get(
        'trending',
        queryParameters: _listParameters(type, page),
      ));

  Future<Map<String, dynamic>?> findUuidByTmdbId({
    required int tmdbId,
    required String type,
    String? title,
    String? providerId,
    List<String> alternativeTitles = const [],
    bool metadataOnly = false,
    bool refresh = false,
  }) async {
    Future<Map<String, dynamic>?> resolve() => _resolveByTmdbId(
          tmdbId: tmdbId,
          type: type,
          title: title,
          providerId: providerId,
          alternativeTitles: alternativeTitles,
          metadataOnly: metadataOnly,
        );
    if (!metadataOnly) return resolve();
    final token = await _getIdToken();
    final key =
        '$_backendUrl|$token|${type.toLowerCase()}|$tmdbId|${providerId ?? ''}';
    final cached = _infoCache[key];
    if (!refresh &&
        cached != null &&
        _now().difference(cached.fetchedAt) < _infoCacheLifetime) {
      return Map<String, dynamic>.from(cached.data);
    }
    final pending = _pendingInfo[key];
    if (pending != null) {
      final data = await pending;
      return data == null ? null : Map<String, dynamic>.from(data);
    }
    final request = resolve();
    _pendingInfo[key] = request;
    try {
      final data = await request;
      if (data != null && data.isNotEmpty) {
        _infoCache.remove(key);
        while (_infoCache.length >= _maxInfoEntries) {
          _infoCache.remove(_infoCache.keys.first);
        }
        _infoCache[key] =
            (fetchedAt: _now(), data: Map<String, dynamic>.from(data));
      }
      return data;
    } finally {
      _pendingInfo.remove(key);
    }
  }

  Future<Map<String, dynamic>?> _resolveByTmdbId({
    required int tmdbId,
    required String type,
    String? title,
    String? providerId,
    List<String> alternativeTitles = const [],
    bool metadataOnly = false,
  }) async {
    final normalizedType = type.toLowerCase();
    if (tmdbId < 1 || (normalizedType != 'movie' && normalizedType != 'tv')) {
      throw ArgumentError(
        'A positive tmdbId and type movie or tv are required.',
      );
    }

    final cacheKey = _cacheKey(tmdbId, normalizedType);
    final cataloguePages = <String, Films365ListEnvelope>{};
    Map<String, dynamic>? matchedMetadata;
    final attemptedIds = <String>{};
    Future<Map<String, dynamic>?> resolveId(String id) async {
      final uuid = id.trim();
      if (uuid.isEmpty || !attemptedIds.add(uuid)) return null;
      try {
        final metadata =
            await _detailsForUuid(type: normalizedType, uuid: uuid);
        if (metadata != null && metadata.isNotEmpty) {
          _uuidCache[cacheKey] = uuid;
          matchedMetadata ??= metadata;
          if (metadataOnly ||
              normalizedType == 'tv' ||
              hasMovieDownloadLink(metadata)) {
            return metadata;
          }
        }
      } on Films365RequestException catch (error) {
        if (error.statusCode != 404) rethrow;
        _uuidCache.remove(cacheKey);
      }
      return null;
    }

    final suppliedUuid = providerId?.trim();
    final cachedUuid = suppliedUuid != null && suppliedUuid.isNotEmpty
        ? suppliedUuid
        : _uuidCache[cacheKey];
    if (cachedUuid != null) {
      final metadata = await resolveId(cachedUuid);
      if (metadata != null) return metadata;
    }

    if (metadataOnly) {
      try {
        final response = await details(
          type: normalizedType == 'movie'
              ? Films365DetailsType.movie
              : Films365DetailsType.tv,
          tmdbId: tmdbId,
        );
        if (response is Map && response.isNotEmpty) {
          final id = response['id'];
          if (id is String && id.trim().isNotEmpty) {
            _uuidCache[cacheKey] = id.trim();
          }
          return _downloadMetadata(response,
              uuid: id is String ? id.trim() : null);
        }
      } on Films365RequestException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
    }

    String? cacheMatch(
      Iterable<Map<String, dynamic>> items, {
      String? fallbackType,
    }) {
      for (final item in items) {
        final itemType = item['type'] ?? fallbackType;
        final id = item['id'];
        if (item['tmdbId'].toString() == tmdbId.toString() &&
            itemType?.toString().toLowerCase() == normalizedType &&
            id is String &&
            id.trim().isNotEmpty &&
            !attemptedIds.contains(id.trim())) {
          return id.trim();
        }
      }
      return null;
    }

    final titles = <String>{
      if (title != null && title.trim().isNotEmpty) title.trim(),
      ...alternativeTitles
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    };
    for (final query in titles.take(metadataOnly ? 1 : titles.length)) {
      Object? response;
      try {
        response = await search(query: query);
      } on Films365RequestException catch (error) {
        if (error.source == 'firebase-auth') rethrow;
      } on TimeoutException {
      } on http.ClientException {
      }
      if (response is Films365SearchEnvelope) {
        final typedResults =
            normalizedType == 'movie' ? response.movies : response.tvs;
        final id = cacheMatch(typedResults, fallbackType: normalizedType) ??
            cacheMatch(response.all);
        if (id != null) {
          final metadata = await resolveId(id);
          if (metadata != null) return metadata;
        }
      }
    }

    if (metadataOnly) return matchedMetadata;

    if (titles.isNotEmpty) {
      for (final endpoint in ['popular', 'trending', 'latest']) {
        Object? response;
        try {
          response = await _get(endpoint,
              queryParameters: {'type': 'all', 'page': '1'});
        } on Films365RequestException catch (error) {
          if (error.source == 'firebase-auth') rethrow;
        } on TimeoutException {
        } on http.ClientException {
        }
        if (response == null) continue;
        final envelope = Films365ListEnvelope.fromJson(_responseMap(response));
        cataloguePages[endpoint] = envelope;
        final id = cacheMatch(envelope.results);
        if (id != null) {
          final metadata = await resolveId(id);
          if (metadata != null) return metadata;
        }
      }
    }

    try {
      final directDetails = await details(
        type: normalizedType == 'movie'
            ? Films365DetailsType.movie
            : Films365DetailsType.tv,
        tmdbId: tmdbId,
      );
      if (directDetails is Map) {
        final id = directDetails['id'];
        if (id is String && id.trim().isNotEmpty) {
          _uuidCache[cacheKey] = id.trim();
        }
        if (directDetails.isNotEmpty) {
          final metadata = _downloadMetadata(directDetails,
              uuid: id is String ? id.trim() : null);
          if (normalizedType == 'tv' || hasMovieDownloadLink(metadata)) {
            return metadata;
          }
          matchedMetadata ??= metadata;
          if (id is String) {
            final providerMetadata = await resolveId(id);
            if (providerMetadata != null) return providerMetadata;
          }
        }
      }
    } on Films365RequestException catch (error) {
      if (error.statusCode != 404) rethrow;
    }

    if (matchedMetadata != null) return matchedMetadata;

    for (final endpoint in ['trending', 'popular', 'latest']) {
      for (var page = 1; page <= 10; page++) {
        var envelope = page == 1 ? cataloguePages[endpoint] : null;
        if (envelope == null) {
          final response = await _get(endpoint, queryParameters: {
            'type': 'all',
            'page': '$page',
          });
          if (response == null) break;
          envelope = Films365ListEnvelope.fromJson(_responseMap(response));
        }
        final id = cacheMatch(envelope.results);
        if (id != null) {
          final metadata = await resolveId(id);
          if (metadata != null) return metadata;
          if (matchedMetadata != null) return matchedMetadata;
        }
        if (page >= envelope.totalPages) break;
      }
    }

    const genres = [
      'Action',
      'Adventure',
      'Animation',
      'Comedy',
      'Crime',
      'Drama',
      'Fantasy',
      'Horror',
    ];
    final contentType = normalizedType == 'movie'
        ? Films365ContentType.movie
        : Films365ContentType.tv;
    for (final genre in genres) {
      for (var page = 1; page <= 3; page++) {
        final response = await _get('explore', queryParameters: {
          'type': contentType.name,
          'page': '$page',
          'genre': genre,
        });
        if (response == null) break;
        final envelope = Films365ListEnvelope.fromJson(_responseMap(response));
        final id = cacheMatch(envelope.results);
        if (id != null) {
          final metadata = await resolveId(id);
          if (metadata != null) return metadata;
          if (matchedMetadata != null) return matchedMetadata;
        }
        if (page >= envelope.totalPages) break;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _detailsForUuid({
    required String type,
    required String uuid,
  }) async {
    final detailsResponse = await details(
      type:
          type == 'movie' ? Films365DetailsType.movie : Films365DetailsType.tv,
      id: uuid,
    );
    if (detailsResponse is! Map) return null;
    if (detailsResponse.isEmpty) return null;
    return _downloadMetadata(detailsResponse, uuid: uuid);
  }

  Map<String, dynamic> _downloadMetadata(Map response, {String? uuid}) {
    final metadata = Map<String, dynamic>.from(response);
    final downloadUrl = metadata['downloadUrl'];
    metadata['uuid'] = uuid;
    if (downloadUrl is String) metadata['downloadUrl'] = downloadUrl.trim();
    metadata['downloadUrlFetchedAt'] = DateTime.now().toUtc().toIso8601String();
    return metadata;
  }

  Future<Object?> popular({
    Films365ContentType type = Films365ContentType.all,
    int page = 1,
  }) =>
      _listItems(_get(
        'popular',
        queryParameters: _listParameters(type, page),
      ));

  Future<Object?> latest({
    Films365ContentType type = Films365ContentType.all,
    int page = 1,
  }) =>
      _listItems(_get(
        'latest',
        queryParameters: _listParameters(type, page),
      ));

  Future<Object?> explore({
    Films365ContentType type = Films365ContentType.all,
    int page = 1,
    int? limit,
    String? genre,
    double? minRating,
    double? maxRating,
    int? minYear,
    int? maxYear,
    Films365SortBy? sortBy,
    Films365SortOrder? order,
  }) {
    if (page < 1 || (limit != null && limit < 1)) {
      throw ArgumentError('Page and limit must be positive integers.');
    }

    final parameters = <String, String>{
      'type': type.name,
      'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (minRating != null) 'min_rating': '$minRating',
      if (maxRating != null) 'max_rating': '$maxRating',
      if (minYear != null) 'min_year': '$minYear',
      if (maxYear != null) 'max_year': '$maxYear',
      if (sortBy != null) 'sort_by': sortBy.name,
      if (order != null) 'order': order.name,
    };
    return _listItems(_get('explore', queryParameters: parameters));
  }

  Future<Object?> search({required String query}) async {
    if (query.trim().isEmpty) {
      throw ArgumentError.value(query, 'query', 'Must not be empty.');
    }
    final response = await _postJson('search', {'query': query});
    if (response == null) return null;
    return Films365SearchEnvelope.fromJson(_responseMap(response));
  }

  Future<Object?> details({
    required Films365DetailsType type,
    String? id,
    int? tmdbId,
  }) async {
    if ((id == null || id.trim().isEmpty) == (tmdbId == null)) {
      throw ArgumentError('Provide exactly one of id or tmdbId.');
    }
    final response = await _get('details', queryParameters: {
      'type': type.name,
      if (id != null) 'id': id,
      if (tmdbId != null) 'tmdbId': '$tmdbId',
    });
    if (response == null) return null;
    return Films365DetailsEnvelope.fromJson(_responseMap(response)).data;
  }

  Future<Object?> person({
    required String type,
    required int tmdbId,
  }) async {
    if (type.trim().isEmpty || tmdbId < 1) {
      throw ArgumentError('A person type and positive tmdbId are required.');
    }
    final response = await _get('person', queryParameters: {
      'type': type,
      'tmdbId': '$tmdbId',
    });
    if (response == null) return null;
    return Films365DetailsEnvelope.fromJson(_responseMap(response)).data;
  }

  Future<Object?> torrentLink({required String link}) {
    if (link.trim().isEmpty) {
      throw ArgumentError.value(link, 'link', 'Must not be empty.');
    }
    return _postJson('details/torrent-link', {'link': link});
  }

  Map<String, String> _listParameters(Films365ContentType type, int page) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be a positive integer.');
    }
    return {'type': type.name, 'page': '$page'};
  }

  Future<Object?> _get(
    String path, {
    Map<String, String> queryParameters = const {},
  }) =>
      _request(
        path,
        method: 'GET',
        queryParameters: queryParameters,
      );

  Future<Object?> _postJson(String path, Map<String, Object?> body) => _request(
        path,
        method: 'POST',
        body: jsonEncode(body),
        contentType: 'application/json',
      );

  Future<List<Films365Item>?> _listItems(Future<Object?> responseFuture) async {
    final response = await responseFuture;
    if (response == null) return null;
    final envelope = Films365ListEnvelope.fromJson(_responseMap(response));
    return envelope.results.map(Films365Item.fromJson).toList();
  }

  Map<String, dynamic> _responseMap(Object response) {
    if (response is Map) return response.cast<String, dynamic>();
    throw const FormatException('Expected a JSON object response.');
  }

  Future<Object?> _request(
    String path, {
    required String method,
    Map<String, String> queryParameters = const {},
    String? body,
    String? contentType,
  }) async {
    final token = await _getIdToken();
    if (token == null || token.trim().isEmpty) {
      throw StateError('Sign in is required to use the FILMS365 catalogue.');
    }

    if (_backendUrl.isEmpty) {
      throw StateError(
        'MOVIE_DOWNLOAD_API_BASE_URL must point to the deployed backend proxy.',
      );
    }

    final uri = Uri.parse('$_backendUrl$_films365ApiPath/$path').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    final headers = {'Authorization': 'Bearer $token'};
    if (contentType != null) headers['Content-Type'] = contentType;

    Future<http.Response> sendRequest() async {
      final response = await (method == 'GET'
          ? _client.get(uri, headers: headers).timeout(_requestTimeout)
          : _client
              .post(uri, headers: headers, body: body)
              .timeout(_requestTimeout));
      const endpoints = {
        'trending',
        'popular',
        'latest',
        'explore',
        'search',
        'details',
        'person',
        'details/torrent-link',
      };
      logHttpDiagnostic(
        endpoint: endpoints.contains(path) ? '/api/mobile/$path' : '/api/other',
        status: response.statusCode,
        headers: response.headers,
      );
      return response;
    }

    var response = await sendRequest();
    if (response.statusCode == 401 &&
        response.headers['x-moviehub-response-source'] == 'firebase-auth') {
      final refreshedToken = await _getIdToken(forceRefresh: true);
      if (refreshedToken != null && refreshedToken.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $refreshedToken';
        final retryResponse = await sendRequest();
        if (retryResponse.statusCode == 401) {
          throw Films365RequestException(
            401,
            source: retryResponse.headers['x-moviehub-response-source'],
          );
        }
        response = retryResponse;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Films365RequestException(
        response.statusCode,
        source: response.headers['x-moviehub-response-source'],
      );
    }

    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<String?> _getIdToken({bool forceRefresh = false}) async {
    final provider = _idTokenProvider;
    if (provider != null) return provider();
    return await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
  }
}

class Films365RequestException implements Exception {
  const Films365RequestException(this.statusCode, {this.source});
  final int statusCode;
  final String? source;

  @override
  String toString() => 'Movie download service request failed ($statusCode).';
}
