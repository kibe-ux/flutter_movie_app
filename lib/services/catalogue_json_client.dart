import 'dart:convert';
import 'package:http/http.dart' as http;

/// A bounded, short-lived browsing cache with shared in-flight requests.
class CatalogueJsonClient {
  CatalogueJsonClient(
      {http.Client? client,
      DateTime Function()? now,
      this.ttl = const Duration(minutes: 5)})
      : _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration ttl;
  final _cache = <Uri, ({DateTime at, Map<String, dynamic> data})>{};
  final _pending = <Uri, Future<Map<String, dynamic>>>{};
  bool _closed = false;

  Future<Map<String, dynamic>> get(Uri uri, {bool refresh = false}) async {
    final cached = _cache[uri];
    if (!refresh && cached != null && _now().difference(cached.at) < ttl) {
      return cached.data;
    }
    final pending = _pending[uri];
    if (pending != null) return pending;
    final request = _fetch(uri);
    _pending[uri] = request;
    try {
      return await request;
    } finally {
      _pending.remove(uri);
    }
  }

  Future<Map<String, dynamic>> _fetch(Uri uri) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('Catalogue unavailable');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid catalogue response');
    }
    if (!_closed) {
      _cache.remove(uri);
      if (_cache.length >= 32) _cache.remove(_cache.keys.first);
      _cache[uri] = (at: _now(), data: decoded);
    }
    return decoded;
  }

  void close() {
    _closed = true;
    _cache.clear();
    _client.close();
  }
}
