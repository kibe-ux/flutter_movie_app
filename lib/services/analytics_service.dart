import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Log user sign-in
  static Future<void> logUserSignIn({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Analytics error (logUserSignIn): $e');
    }
  }

  // Log user sign-out
  static Future<void> logUserSignOut() async {
    try {
      await _analytics.logEvent(
        name: 'user_sign_out',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error (logUserSignOut): $e');
    }
  }

  // Log movie view
  static Future<void> logMovieView({
    required int movieId,
    required String movieTitle,
    double? rating,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'movie_view',
        parameters: {
          'movie_id': movieId,
          'movie_title': movieTitle,
          'rating': rating ?? 0.0,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error (logMovieView): $e');
    }
  }

  // Log search query
  static Future<void> logSearch({required String query}) async {
    try {
      await _analytics.logSearch(
        searchTerm: query,
      );
    } catch (e) {
      debugPrint('Analytics error (logSearch): $e');
    }
  }

  // Log favorite action
  static Future<void> logFavoriteAction({
    required int movieId,
    required String movieTitle,
    required bool isFavorite,
  }) async {
    try {
      await _analytics.logEvent(
        name: isFavorite ? 'add_to_favorites' : 'remove_from_favorites',
        parameters: {
          'movie_id': movieId,
          'movie_title': movieTitle,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error (logFavoriteAction): $e');
    }
  }

  // Log download action
  static Future<void> logDownloadAction({
    required int movieId,
    required String movieTitle,
    required bool isDownloading,
  }) async {
    try {
      await _analytics.logEvent(
        name: isDownloading ? 'start_download' : 'cancel_download',
        parameters: {
          'movie_id': movieId,
          'movie_title': movieTitle,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error (logDownloadAction): $e');
    }
  }

  // Log video playback
  static Future<void> logVideoPlayback({
    required int movieId,
    required String movieTitle,
    required int duration, // in seconds
    required int position, // in seconds
    required String source, // 'web' or 'local'
  }) async {
    try {
      await _analytics.logEvent(
        name: 'video_playback',
        parameters: {
          'movie_id': movieId,
          'movie_title': movieTitle,
          'duration': duration,
          'position': position,
          'source': source,
          'progress': ((position / duration) * 100).toStringAsFixed(2),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error (logVideoPlayback): $e');
    }
  }

  // Log screen view
  static Future<void> logScreenView({required String screenName}) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics error (logScreenView): $e');
    }
  }

  // Log app rating
  static Future<void> logAppRating({
    required int rating, // 1-5
    required String feedback,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_rating',
        parameters: {
          'rating': rating,
          'feedback': feedback,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Analytics error (logAppRating): $e');
    }
  }

  // Log custom event
  static Future<void> logCustomEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters ??
            {
              'timestamp': DateTime.now().toIso8601String(),
            },
      );
    } catch (e) {
      debugPrint('Analytics error (logCustomEvent): $e');
    }
  }

  // Set user ID
  static Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics error (setUserId): $e');
    }
  }

  // Set user properties
  static Future<void> setUserProperties({
    String? preferredGenre,
    String? accountType,
    bool? isVerified,
  }) async {
    try {
      if (preferredGenre != null) {
        await _analytics.setUserProperty(
          name: 'preferred_genre',
          value: preferredGenre,
        );
      }
      if (accountType != null) {
        await _analytics.setUserProperty(
          name: 'account_type',
          value: accountType,
        );
      }
      if (isVerified != null) {
        await _analytics.setUserProperty(
          name: 'email_verified',
          value: isVerified.toString(),
        );
      }
    } catch (e) {
      debugPrint('Analytics error (setUserProperties): $e');
    }
  }
}
