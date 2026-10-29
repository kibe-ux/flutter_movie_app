import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl; // time to live

  CacheEntry({
    required this.data,
    required this.ttl,
  }) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt).compareTo(ttl) > 0;
}

class CacheService {
  static final Map<String, CacheEntry<dynamic>> _memCache = {};
  static const int _maxMemCacheSize = 50;
  static const String _prefKey = 'cache_';

  // Memory cache operations
  static void setMemCache<T>(String key, T value, {Duration? ttl}) {
    if (_memCache.length >= _maxMemCacheSize) {
      // Remove oldest entry
      final oldest = _memCache.keys.first;
      _memCache.remove(oldest);
    }

    _memCache[key] = CacheEntry<T>(
      data: value,
      ttl: ttl ?? const Duration(hours: 1),
    );
  }

  static T? getMemCache<T>(String key) {
    final entry = _memCache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _memCache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  static void removeMemCache(String key) {
    _memCache.remove(key);
  }

  static void clearMemCache() {
    _memCache.clear();
  }

  // Persistent cache operations
  static Future<void> setDiskCache(
    String key,
    dynamic value, {
    Duration ttl = const Duration(days: 7),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': value,
        'ttl_ms': ttl.inMilliseconds,
        'created_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_prefKey + key, jsonEncode(cacheData));
    } catch (e) {
      debugPrint('Disk cache set error: $e');
    }
  }

  static Future<T?> getDiskCache<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_prefKey + key);
      if (cacheJson == null) return null;

      final cacheData = jsonDecode(cacheJson) as Map<String, dynamic>;
      final createdAt = DateTime.parse(cacheData['created_at'] as String);
      final ttlMs = cacheData['ttl_ms'] as int;
      final ttl = Duration(milliseconds: ttlMs);

      // Check if expired
      if (DateTime.now().difference(createdAt).compareTo(ttl) > 0) {
        await prefs.remove(_prefKey + key);
        return null;
      }

      return cacheData['data'] as T?;
    } catch (e) {
      debugPrint('Disk cache get error: $e');
      return null;
    }
  }

  static Future<void> removeDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey + key);
    } catch (e) {
      debugPrint('Disk cache remove error: $e');
    }
  }

  static Future<void> clearDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_prefKey)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Disk cache clear error: $e');
    }
  }

  // Get memory usage stats
  static Map<String, int> getMemCacheStats() {
    return {
      'entries': _memCache.length,
      'max_entries': _maxMemCacheSize,
    };
  }

  // Smart cache - uses both memory and disk
  static Future<T?> getSmartCache<T>(String key) async {
    // Try memory first
    final memValue = getMemCache<T>(key);
    if (memValue != null) return memValue;

    // Try disk
    final diskValue = await getDiskCache<T>(key);
    if (diskValue != null) {
      // Cache in memory for quick access
      setMemCache<T>(key, diskValue, ttl: const Duration(minutes: 30));
      return diskValue;
    }

    return null;
  }

  static Future<void> setSmartCache<T>(
    String key,
    T value, {
    Duration memTtl = const Duration(hours: 1),
    Duration diskTtl = const Duration(days: 7),
  }) async {
    // Cache in memory
    setMemCache<T>(key, value, ttl: memTtl);
    // Cache on disk
    await setDiskCache(key, value, ttl: diskTtl);
  }
}
