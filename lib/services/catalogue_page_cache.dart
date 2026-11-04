import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shares public catalogue pages across screens and app restarts.
class CataloguePageCache {
  CataloguePageCache({
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 15),
    this.persist = true,
    this.maxEntries = 32,
    this.maxBytes = 1024 * 1024,
  }) : _now = now ?? DateTime.now;

  static const storageKey = 'catalogue_pages_v1';
  final DateTime Function() _now;
  final Duration ttl;
  final bool persist;
  final int maxEntries;
  final int maxBytes;
  final _entries = <String, ({DateTime at, String body, int bytes})>{};
  final _pending = <String, Future<String>>{};
  Future<void>? _restoring;
  Future<void> _writing = Future.value();
  SharedPreferences? _preferences;

  Future<String> get(Uri uri, Future<String> Function() fetch,
      {bool refresh = false}) async {
    // Include every query parameter and credential in the identity without
    // writing API keys or request URLs into preferences.
    final canonical = uri.replace(queryParameters: {
      for (final key in uri.queryParametersAll.keys.toList()..sort())
        key: uri.queryParametersAll[key]!,
    });
    final key = sha256.convert(utf8.encode(canonical.toString())).toString();
    final pending = _pending[key];
    if (pending != null) return pending;
    final request = _readOrFetch(key, fetch, refresh);
    _pending[key] = request;
    try {
      return await request;
    } finally {
      _pending.remove(key);
    }
  }

  bool _fresh(DateTime at) {
    final age = _now().difference(at);
    return !age.isNegative && age < ttl;
  }

  Future<String> _readOrFetch(
      String key, Future<String> Function() fetch, bool refresh) async {
    await (_restoring ??= _restore());
    final cached = _entries[key];
    if (!refresh && cached != null && _fresh(cached.at)) {
      return cached.body;
    }
    // Only successful, validated responses reach this point.
    final body = await fetch();
    _entries.remove(key);
    final bytes = utf8.encode(body).length;
    if (bytes <= maxBytes && maxEntries > 0) {
      _entries[key] = (at: _now(), body: body, bytes: bytes);
    }
    _trim();
    await _save();
    return body;
  }

  void _trim() {
    _entries.removeWhere((_, entry) => !_fresh(entry.at));
    var bytes = _entries.values.fold(0, (sum, entry) => sum + entry.bytes);
    while (_entries.isNotEmpty &&
        (_entries.length > maxEntries || bytes > maxBytes)) {
      bytes -= _entries.remove(_entries.keys.first)!.bytes;
    }
  }

  Future<void> _restore() async {
    if (!persist) return;
    try {
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences!.getString(storageKey);
      if (saved == null) return;
      final entries = jsonDecode(saved) as Map<String, dynamic>;
      for (final entry in entries.entries) {
        try {
          final value = entry.value as Map<String, dynamic>;
          final at = DateTime.fromMillisecondsSinceEpoch(value['at'] as int);
          final body = value['body'] as String;
          final data = jsonDecode(body);
          if (!_fresh(at) || data is! Map || data['results'] is! List) continue;
          _entries[entry.key] =
              (at: at, body: body, bytes: utf8.encode(body).length);
        } catch (_) {
          // A damaged entry must never prevent a fresh network request.
        }
      }
      _trim();
    } catch (_) {
      // Browsing still works when local storage is unavailable or damaged.
    }
  }

  Future<void> _save() {
    if (_preferences == null) return Future.value();
    // Serialize writes so responses for different pages cannot overwrite a
    // newer snapshot with an older one.
    return _writing = _writing.then((_) async {
      try {
        await _preferences!.setString(
            storageKey,
            jsonEncode({
              for (final entry in _entries.entries)
                entry.key: {
                  'at': entry.value.at.millisecondsSinceEpoch,
                  'body': entry.value.body,
                },
            }));
      } catch (_) {
        // Cache persistence is optional; retain the working memory cache.
      }
    });
  }
}
