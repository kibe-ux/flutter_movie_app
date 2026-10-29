import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logUserSignIn({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Analytics error (logUserSignIn): $e');
    }
  }

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

  static Future<void> logSearch({required String query}) async {
    try {
      await _analytics.logSearch(
        searchTerm: query,
      );
    } catch (e) {
      debugPrint('Analytics error (logSearch): $e');
    }
  }

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

  static Future<void> logVideoPlayback({
    required int movieId,
    required String movieTitle,
    required int duration,
    required int position,
    required String source,
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

  static Future<void> logScreenView({required String screenName}) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics error (logScreenView): $e');
    }
  }

  static Future<void> logAppRating({
    required int rating,
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

  static Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics error (setUserId): $e');
    }
  }

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
