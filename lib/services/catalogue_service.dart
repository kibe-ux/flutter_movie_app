import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/movie_download_availability.dart';

class CatalogueLoadException implements Exception {
  const CatalogueLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CataloguePage {
  const CataloguePage({required this.items, required this.hasMore});

  final List<Map<String, dynamic>> items;
  final bool hasMore;
}

class CatalogueService {
  const CatalogueService({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  Future<CataloguePage> fetchPage(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw const CatalogueLoadException(
            'Movies are temporarily unavailable. Please try again.');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['results'] is! List) {
        throw const FormatException('Invalid movie list');
      }
      final results = data['results'] as List;
      final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
      final totalPages = data['total_pages'];
      return CataloguePage(
        items: filterReleasedMovies(results)
            .where((item) => item['id'] is int)
            .toList(),
        hasMore:
            results.isNotEmpty && (totalPages is! num || page < totalPages),
      );
    } on TimeoutException {
      throw const CatalogueLoadException(
          'The connection took too long. Please try again.');
    } on http.ClientException {
      throw const CatalogueLoadException(
          'Check your connection and try again.');
    } on FormatException {
      throw const CatalogueLoadException(
          'We could not read the movie list. Please try again.');
    }
  }
}
