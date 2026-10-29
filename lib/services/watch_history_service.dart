import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WatchHistoryEntry {
  final int movieId;
  final String title;
  final String? posterPath;
  final double voteAverage;
  final DateTime watchedAt;
  final int watchDuration; // in seconds

  WatchHistoryEntry({
    required this.movieId,
    required this.title,
    this.posterPath,
    required this.voteAverage,
    DateTime? watchedAt,
    this.watchDuration = 0,
  }) : watchedAt = watchedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'title': title,
        'posterPath': posterPath,
        'voteAverage': voteAverage,
        'watchedAt': watchedAt.toIso8601String(),
        'watchDuration': watchDuration,
      };

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return WatchHistoryEntry(
      movieId: json['movieId'] as int,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      voteAverage: (json['voteAverage'] as num).toDouble(),
      watchedAt: DateTime.parse(json['watchedAt'] as String),
      watchDuration: json['watchDuration'] as int? ?? 0,
    );
  }
}

class WatchHistoryService {
  static String _getUserKey(String baseKey) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${baseKey}_$userId';
  }

  static Future<List<WatchHistoryEntry>> getWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_getUserKey('watch_history')) ?? [];

    return historyJson
        .map((json) => WatchHistoryEntry.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }

  static Future<void> addToHistory(WatchHistoryEntry entry) async {
    final history = await getWatchHistory();

    // Remove if already exists (to update position)
    history.removeWhere((h) => h.movieId == entry.movieId);

    // Add new entry at the beginning
    history.insert(0, entry);

    // Keep only last 100 entries
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }

    await _saveHistory(history);
  }

  static Future<void> removeFromHistory(int movieId) async {
    final history = await getWatchHistory();
    history.removeWhere((h) => h.movieId == movieId);
    await _saveHistory(history);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getUserKey('watch_history'));
  }

  static Future<void> _saveHistory(List<WatchHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = history.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_getUserKey('watch_history'), historyJson);
  }

  static Future<WatchHistoryEntry?> getLastWatched() async {
    final history = await getWatchHistory();
    return history.isNotEmpty ? history.first : null;
  }

  static Future<int> getTotalWatchTime() async {
    final history = await getWatchHistory();
    return history.fold<int>(
        0, (sum, entry) => sum + entry.watchDuration);
  }

  static Future<int> getTotalMoviesWatched() async {
    final history = await getWatchHistory();
    return history.length;
  }
}
