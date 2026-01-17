import 'package:flutter/material.dart';

/// Central location for all theme constants and colors
class AppTheme {
  // Colors
  static const Color primaryBlue = Color(0xFF00D4FF);
  static const Color secondaryCyan = Color(0xFF0099CC);
  static const Color netflixBlack = Color(0xFF0A0A0A);
  static const Color darkGrey = Color(0xFF141414);
  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color netflixRed = Color(0xFFE50914);
  static const Color white = Colors.white;
  static const Color white70 = Colors.white70;
  static const Color white54 = Colors.white54;
  static const Color white38 = Colors.white38;
  static const Color white30 = Colors.white30;
  static const Color white12 = Colors.white12;
  static const Color transparent = Colors.transparent;
  static const Color amber = Colors.amber;
  static const Color green = Colors.green;
  static const Color red = Colors.red;
  static const Color orange = Colors.orange;
  static const Color black = Colors.black;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacing2XL = 24.0;
  static const double spacing3XL = 30.0;

  // Border Radius
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 15.0;
  static const double radiusXL = 20.0;
  static const double radiusCircle = 50.0;

  // Font Sizes
  static const double fontXS = 10.0;
  static const double fontS = 12.0;
  static const double fontM = 16.0;
  static const double fontL = 18.0;
  static const double fontXL = 20.0;
  static const double font2XL = 22.0;
  static const double font3XL = 24.0;

  // Icon Sizes
  static const double iconS = 16.0;
  static const double iconM = 18.0;
  static const double iconL = 22.0;
  static const double iconXL = 50.0;
  static const double icon2XL = 80.0;

  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVarySlow = Duration(milliseconds: 1000);

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration downloadTimeout = Duration(seconds: 300);

  // Widget Dimensions
  static const double adBannerHeight = 50.0;
  static const double posterWidth = 120.0;
  static const double posterHeight = 180.0;
  static const double castImageSize = 80.0;
  static const double castContainerWidth = 100.0;
  static const double castItemHeight = 160.0;
  static const double expandedAppBarHeight = 300.0;

  // Opacity Values
  static const double opacity05 = 0.05;
  static const double opacity1 = 0.1;
  static const double opacity3 = 0.3;
  static const double opacity5 = 0.5;
  static const double opacity7 = 0.7;
  static const double opacity8 = 0.8;

  // API Constants
  /// TMDB API Key - Use environment variable for production
  /// Run: flutter run --dart-define=TMDB_API_KEY=your_production_key
  static String get apiKey => String.fromEnvironment('TMDB_API_KEY',
      defaultValue: '9c12c3b471405cfbfeca767fa3ea8907'); // Dev fallback

  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBase = 'https://image.tmdb.org/t/p/w300';
  static const String posterBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w780';
  static const String profileBase = 'https://image.tmdb.org/t/p/w185';

  // Google Ads Unit IDs - Replace with production IDs before release
  /// Banner Ad Unit ID - REPLACE WITH PRODUCTION ID
  static const String bannerAdUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy'; // TODO: Update with production ID

  /// Interstitial Ad Unit ID - REPLACE WITH PRODUCTION ID
  static const String interstitialAdUnitId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy'; // TODO: Update with production ID
}
