import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyList {
  MyList._internal();
  static final MyList _instance = MyList._internal();
  factory MyList() => _instance;
  static const String _storageKey = 'my_list_ids';
  final Set<int> _ids = {};
  bool _initialized = false;
  Timer? _saveTimer;

  /// Call ONCE at app start (in main.dart)
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? [];
      _ids
        ..clear()
        ..addAll(
          stored.map((e) => int.tryParse(e)).whereType<int>(),
        );
    } catch (e) {
      debugPrint('Failed to load MyList: $e');
      _ids.clear();
    }
    _initialized = true;
  }

  /// Ensures init() has been called before use.
  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Debounced persist: only the last call within 300 ms actually writes.
  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _storageKey,
          _ids.map((e) => e.toString()).toList(),
        );
      } catch (e) {
        debugPrint('Failed to save MyList: $e');
      }
    });
  }

  /// Persist immediately (no debounce), awaitable.
  Future<void> _persistNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storageKey,
        _ids.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      debugPrint('Failed to save MyList: $e');
    }
  }

  void add(int id) {
    if (!_initialized) return;
    if (_ids.add(id)) _persist();
  }

  void remove(int id) {
    if (!_initialized) return;
    if (_ids.remove(id)) _persist();
  }

  void toggle(int id) {
    if (!_initialized) return;
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    _persist();
  }

  Future<void> toggleAndWait(int id) async {
    if (!_initialized) return;
    if (_ids.contains(id)) {
      _ids.remove(id);
    } else {
      _ids.add(id);
    }
    await _persistNow();
  }

  bool contains(int id) => _ids.contains(id);
  Set<int> get all => Set<int>.from(_ids);

  Future<void> clear() async {
    if (!_initialized) return;
    _ids.clear();
    await _persistNow();
  }

  bool get isInitialized => _initialized;

  @override
  String toString() => 'MyList(${_ids.length} items)';
}
