import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/films365_models.dart';

enum Films365ContentType { all, movie, tv }

enum Films365DetailsType { movie, tv }

enum Films365SortBy { popularity, rating, date }

enum Films365SortOrder { asc, desc }

/// Authenticated client for the server-side FILMS365 proxy.
///
/// The upstream API key is never sent to or stored by this client.
class Films365ApiService {
  Films365ApiService({
    http.Client? client,
    String Function()? apiBaseUrlProvider,
    Future<String?> Function()? idTokenProvider,
    Duration requestTimeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _apiBaseUrlProvider = apiBaseUrlProvider,
        _idTokenProvider = idTokenProvider,
        _requestTimeout = requestTimeout;

  static const _debugBackendUrl = 'http://127.0.0.1:3000';
  static const _releaseBackendUrl =
      String.fromEnvironment('MOVIE_DOWNLOAD_API_BASE_URL');
  static const _films365ApiPath = '/api/mobile';
  final http.Client _client;
  final String Function()? _apiBaseUrlProvider;
  final Future<String?> Function()? _idTokenProvider;
  final Duration _requestTimeout;

  bool get isConfigured => _backendUrl.isNotEmpty;

  String get _backendUrl {
    final configuredUrl = _apiBaseUrlProvider?.call() ??
        dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL'];
    final baseUrl =
        configuredUrl ?? (kDebugMode ? _debugBackendUrl : _releaseBackendUrl);
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

  /// Forwards a caller-supplied link to the optional torrent-link endpoint.
  /// The link is not logged or otherwise retained by this client.
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
    final usesFirebaseAuth = _idTokenProvider == null;
    final token = await _getIdToken(forceRefresh: usesFirebaseAuth);
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

    Future<http.Response> sendRequest() => method == 'GET'
        ? _client.get(uri, headers: headers).timeout(_requestTimeout)
        : _client
            .post(uri, headers: headers, body: body)
            .timeout(_requestTimeout);

    var response = await sendRequest();
    if (response.statusCode == 401 && usesFirebaseAuth) {
      final refreshedToken = await _getIdToken(forceRefresh: true);
      if (refreshedToken != null && refreshedToken.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $refreshedToken';
        final retryResponse = await sendRequest();
        if (retryResponse.statusCode == 401) {
          throw Exception('FILMS365 $path request failed (401).');
        }
        response = retryResponse;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'FILMS365 $path request failed (${response.statusCode}).',
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
