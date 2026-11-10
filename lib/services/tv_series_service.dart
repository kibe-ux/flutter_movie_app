import 'metadata_list_service.dart';

bool isTvSeries(Map<String, dynamic> item) {
  final type = item['media_type'] ?? item['type'];
  if (type != null) return type.toString().toLowerCase() == 'tv';
  return item['first_air_date'] != null || item['name'] != null;
}

// Movie IDs stay in their existing namespace; episodes get a separate stable ID.
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
  final _metadata = MetadataListService();

  Future<List<Map<String, dynamic>>> seasons(int seriesId) =>
      _metadata.fetch('tv/$seriesId', field: 'seasons');

  Future<List<Map<String, dynamic>>> episodes(int seriesId, int season) =>
      _metadata.fetch('tv/$seriesId/season/$season', field: 'episodes');
}
