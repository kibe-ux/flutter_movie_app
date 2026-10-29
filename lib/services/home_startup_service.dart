import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'catalogue_service.dart';

class HomeStartupData {
  const HomeStartupData({
    required this.connected,
    required this.categories,
    this.categoryErrors = const {},
  });
  final bool connected;
  final Map<String, List<Map<String, dynamic>>> categories;
  final Map<String, String> categoryErrors;
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
    final responses = await Future.wait(endpoints.entries.map((entry) async {
      final uri = Uri.https('api.themoviedb.org', '/3/${entry.value}', {
        'api_key': dotenv.env['MOVIE_API_KEY'] ?? '',
        'language': 'en-US',
        'page': '1',
      });
      try {
        final page = await catalogue.fetchPage(uri);
        return MapEntry(entry.key, page.items);
      } on CatalogueLoadException catch (error) {
        errors[entry.key] = error.message;
        return MapEntry(entry.key, <Map<String, dynamic>>[]);
      }
    }));
    if (errors.length == endpoints.length) {
      throw CatalogueLoadException(errors.values.first);
    }
    final seen = <int>{};
    return HomeStartupData(
        connected: true,
        categoryErrors: errors,
        categories: {
          for (final entry in responses)
            entry.key: entry.value
                .where((movie) => seen.add(movie['id'] as int))
                .toList(),
        });
  }

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
    if (trending.isNotEmpty && trending.first['backdrop_path'] != null) {
      urls.add(
          'https://image.tmdb.org/t/p/w780${trending.first['backdrop_path']}');
    }
    for (final movies
        in data.categories.values.where((items) => items.isNotEmpty).take(1)) {
      for (final movie in movies.take(count)) {
        if (movie['poster_path'] != null) {
          urls.add('https://image.tmdb.org/t/p/w300${movie['poster_path']}');
        }
      }
    }
    await Future.wait(urls.map((url) async {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context,
                onError: (error, stack) {})
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
      }
    }));
  }
}
