import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  static String _getUserKey(String baseKey) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '${baseKey}_$userId';
  }

  static Future<Set<int>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_getUserKey('favorite_movies'));
    if (favoritesJson == null) return {};

    final List<dynamic> favoritesList = json.decode(favoritesJson);
    return favoritesList.map((id) => id as int).toSet();
  }

  static Future<void> addToFavorites(int movieId) async {
    final favorites = await getFavorites();
    favorites.add(movieId);
    await _saveFavorites(favorites);
  }

  static Future<void> removeFromFavorites(int movieId) async {
    final favorites = await getFavorites();
    favorites.remove(movieId);
    await _saveFavorites(favorites);
  }

  static Future<bool> isFavorite(int movieId) async {
    final favorites = await getFavorites();
    return favorites.contains(movieId);
  }

  static Future<void> _saveFavorites(Set<int> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = json.encode(favorites.toList());
    await prefs.setString(_getUserKey('favorite_movies'), favoritesJson);
  }
}
