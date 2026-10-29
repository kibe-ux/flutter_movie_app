import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyList {
  MyList._internal();
  static final MyList _instance = MyList._internal();
  factory MyList() => _instance;
  static const String _storageKey = 'my_list_ids';
  final Set<int> _ids = {};
  bool _initialized = false;
  Timer? _saveTimer;
  String? _currentUserId;

  String _getUserKey() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${_storageKey}_$userId';
  }

  Future<void> init() async {
    if (_initialized) return;
    await _loadData();
    _initialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUserId = user?.uid ?? 'guest';
      if (newUserId != _currentUserId) {
        _currentUserId = newUserId;
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_getUserKey()) ?? [];
      _ids
        ..clear()
        ..addAll(
          stored.map((e) => int.tryParse(e)).whereType<int>(),
        );
    } catch (e) {
      debugPrint('Failed to load MyList: $e');
      _ids.clear();
    }
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _getUserKey(),
          _ids.map((e) => e.toString()).toList(),
        );
      } catch (e) {
        debugPrint('Failed to save MyList: $e');
      }
    });
  }

  Future<void> _persistNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _getUserKey(),
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
