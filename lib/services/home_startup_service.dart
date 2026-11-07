import '../config/home_categories.dart';
import '../utils/catalogue_artwork.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'catalogue_service.dart';

class HomeStartupData {
  const HomeStartupData({
    required this.connected,
    required this.categories,
    this.categoryErrors = const {},
    this.nextCursors = const {},
    this.hasMore = const {},
  });
  final bool connected;
  final Map<String, List<Map<String, dynamic>>> categories;
  final Map<String, String> categoryErrors;
  final Map<String, String?> nextCursors;
  final Map<String, bool> hasMore;
}

class HomeStartupService {
  HomeStartupService({this.catalogue = const CatalogueService()});

  final CatalogueService catalogue;
  static const endpoints = {
    'Trending Today': 'trending/movie/day',
    'Now Playing': 'movie/now_playing',
    'Popular Movies': 'movie/popular',
    'Top Rated': 'movie/top_rated',
  };

  Future<HomeStartupData> load() async {
    final connections = await Connectivity().checkConnectivity();
    if (!connections.any((value) => value != ConnectivityResult.none)) {
      return const HomeStartupData(connected: false, categories: {});
    }
    final errors = <String, String>{};
    final cursors = <String, String?>{};
    final more = <String, bool>{};
    final responses = await Future.wait(endpoints.entries.map((entry) async {
      final uri = homeCategoriesByName[entry.key]!.uri();
      try {
        final page = await catalogue.fetchPage(uri);
        cursors[entry.key] = page.nextCursor;
        more[entry.key] = page.hasMore;
        return MapEntry(entry.key, page.items);
      } on CatalogueLoadException catch (error) {
        errors[entry.key] = error.message;
        return MapEntry(entry.key, <Map<String, dynamic>>[]);
      }
    }));
    if (errors.length == endpoints.length) {
      throw CatalogueLoadException(errors.values.first);
    }
    List<Map<String, dynamic>> unique(List<Map<String, dynamic>> items) {
      final seen = <int>{};
      return items.where((movie) => seen.add(movie['id'] as int)).toList();
    }

    return HomeStartupData(
        connected: true,
        categoryErrors: errors,
        nextCursors: cursors,
        hasMore: more,
        categories: {
          for (final entry in responses) entry.key: unique(entry.value),
        });
  }

  // Warm only the first visible artwork; the screen does not wait for this.
  Future<void> preloadImages(HomeStartupData data, BuildContext context) async {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width < 376
        ? 110
        : width < 430
            ? 120
            : width < 768
                ? 130
                : 160;
    final count = ((width / (cardWidth + 10)).ceil() + 1).clamp(1, 4);
    final urls = <String>{};
    final trending = data.categories['Trending Today'] ?? [];
    if (trending.isNotEmpty) {
      final image =
          catalogueArtwork(trending.first, backdrop: true, size: 'w780') ??
              catalogueArtwork(trending.first);
      if (image != null) urls.add(image);
    }
    for (final movies
        in data.categories.values.where((items) => items.isNotEmpty).take(1)) {
      for (final movie in movies.take(count)) {
        final image = catalogueArtwork(movie, size: 'w300');
        if (image != null) urls.add(image);
      }
    }
    await Future.wait(urls.map((url) async {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context,
                onError: (error, stack) {})
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // The visible image widget can finish loading independently.
      }
    }));
  }
}
