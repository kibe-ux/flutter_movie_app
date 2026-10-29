import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

bool isTvSeries(Map<String, dynamic> item) {
  final type = item['media_type'] ?? item['type'];
  if (type != null) return type.toString().toLowerCase() == 'tv';
  return item['first_air_date'] != null || item['name'] != null;
}

int episodeDownloadId(int episodeId) => 1000000000000 + episodeId;

Map<String, dynamic>? episodeDownloadMetadata(
    Map<String, dynamic>? details, int season, int episode) {
  int? number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');
  Map<String, dynamic>? match(dynamic episodes, {bool nested = false}) {
    if (episodes is! List) return null;
    for (final item in episodes.whereType<Map>()) {
      final ep = number(
          item['episode_number'] ?? item['episodeNumber'] ?? item['number']);
      final sn = number(item['season_number'] ?? item['seasonNumber']);
      if (ep == episode && (sn == season || (nested && sn == null))) {
        final url = item['downloadUrl'];
        final uri = url is String ? Uri.tryParse(url.trim()) : null;
        if (uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty) {
          return Map<String, dynamic>.from(item)..['downloadUrl'] = url!.trim();
        }
      }
    }
    return null;
  }

  final seasons = details?['seasons'];
  if (seasons is List) {
    for (final item in seasons.whereType<Map>()) {
      if (number(item['season_number'] ??
              item['seasonNumber'] ??
              item['number']) ==
          season) {
        final result = match(item['episodes'], nested: true);
        if (result != null) return result;
      }
    }
  }
  return match(details?['episodes']);
}

class TvSeriesService {
  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.https('api.themoviedb.org', '/3/$path', {
      'api_key': dotenv.env['MOVIE_API_KEY'] ?? '',
      'language': 'en-US',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Unable to load TV information');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> seasons(int seriesId) async {
    final details = await _get('tv/$seriesId');
    return _maps(details['seasons']);
  }

  Future<List<Map<String, dynamic>>> episodes(int seriesId, int season) async {
    final details = await _get('tv/$seriesId/season/$season');
    return _maps(details['episodes']);
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : [];
}
