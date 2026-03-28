import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'watch_history_service.dart';
import 'favorites_service.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';

class RecommendationsService {
  static Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    int limit = 10,
  }) async {
    try {
      // Get user's favorites and watch history
      final favorites = await FavoritesService.getFavorites();
      final history = await WatchHistoryService.getWatchHistory();

      if (favorites.isEmpty && history.isEmpty) {
        // If no history, return trending movies
        return _getTrendingMovies(limit);
      }

      // Collect movies to fetch recommendations from
      final moviesToAnalyze = <int>{
        ...favorites,
        ...history.take(5).map((h) => h.movieId),
      }.toList();

      // Fetch recommendations for each movie
      final allRecommendations = <Map<String, dynamic>>[];
      final seenMovieIds = <int>{
        ...favorites,
        ...history.map((h) => h.movieId)
      };

      for (final movieId in moviesToAnalyze.take(3)) {
        try {
          final recs = await _getMovieRecommendations(movieId);
          for (final rec in recs) {
            final movieIdRec = rec['id'] as int?;
            if (movieIdRec != null && !seenMovieIds.contains(movieIdRec)) {
              allRecommendations.add(rec);
              seenMovieIds.add(movieIdRec);
            }
          }
        } catch (e) {
          // Continue with next movie if this fails
        }
      }

      // Sort by vote average and limit
      allRecommendations.sort((a, b) {
        final ratingA = (a['vote_average'] as num?) ?? 0;
        final ratingB = (b['vote_average'] as num?) ?? 0;
        return ratingB.compareTo(ratingA);
      });

      return allRecommendations.take(limit).toList();
    } catch (e) {
      return _getTrendingMovies(limit);
    }
  }

  static Future<List<Map<String, dynamic>>> _getMovieRecommendations(
    int movieId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/movie/$movieId/recommendations?api_key=$apiKey'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? [])
            .where((movie) =>
                movie['poster_path'] != null &&
                movie['title'] != null &&
                (movie['vote_average'] as num? ?? 0) > 5)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getTrendingMovies(
      int limit) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/trending/movie/week?api_key=$apiKey'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? [])
            .where((movie) =>
                movie['poster_path'] != null && movie['title'] != null)
            .take(limit)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getTrendingMovies({
    int limit = 10,
  }) async {
    return _getTrendingMovies(limit);
  }

  static Future<List<Map<String, dynamic>>> getTopRatedMovies({
    int limit = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/movie/top_rated?api_key=$apiKey'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? [])
            .where((movie) =>
                movie['poster_path'] != null && movie['title'] != null)
            .take(limit)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUpcomingMovies({
    int limit = 10,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/movie/upcoming?api_key=$apiKey'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? [])
            .where((movie) =>
                movie['poster_path'] != null && movie['title'] != null)
            .take(limit)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
