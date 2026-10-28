/// Fields supplied by the Film365 Details response, alongside downloadUrl.
List<Map<String, dynamic>> movieInfoRecords(Object? value) {
  if (value is Map) value = value['results'];
  return value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : [];
}

List<String> movieInfoNames(Object? value) {
  if (value is! List) return [];
  return value
      .map((item) => item is Map ? item['name'] : item)
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

class MovieInfoVideo {
  const MovieInfoVideo(
      {required this.name,
      required this.type,
      required this.site,
      required this.uri,
      this.youtubeKey,
      this.isOfficial = false});
  final String name;
  final String type;
  final String site;
  final Uri uri;
  final String? youtubeKey;
  final bool isOfficial;

  static List<MovieInfoVideo> featuredFromDetails(
      Map<String, dynamic> details) {
    final videos = fromDetails(details).asMap().entries.toList();
    int rank(MovieInfoVideo video) {
      final type = video.type.toLowerCase().trim();
      final typeRank = type == 'trailer' ? 0 : (type == 'teaser' ? 1 : 2);
      return typeRank * 2 + (video.isOfficial ? 0 : 1);
    }

    videos.sort((a, b) {
      final difference = rank(a.value).compareTo(rank(b.value));
      return difference == 0 ? a.key.compareTo(b.key) : difference;
    });
    return videos.take(3).map((entry) => entry.value).toList();
  }

  Uri get embedUri => youtubeKey != null
      ? Uri.https('www.youtube.com', '/embed/$youtubeKey', {
          'playsinline': '1',
          'autoplay': '0',
          'rel': '0',
          'origin': 'https://com.moviehub.app',
        })
      : Uri.https('player.vimeo.com', '/video/${uri.pathSegments.last}',
          {'playsinline': '1'});

  static List<MovieInfoVideo> fromDetails(Map<String, dynamic> details) {
    final videos = <MovieInfoVideo>[];
    final seen = <String>{};
    for (final item in movieInfoRecords(details['videos'])) {
      final site = item['site']?.toString().trim().toLowerCase();
      final key = item['key']?.toString().trim() ?? '';
      final type = item['type'] is String ? item['type'] as String : 'Video';
      Uri? uri;
      String? youtubeKey;
      String displaySite;
      if (site == 'youtube' && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(key)) {
        youtubeKey = key;
        displaySite = 'YouTube';
        uri = Uri.https('www.youtube.com', '/watch', {'v': key});
      } else if (site == 'vimeo' && RegExp(r'^\d+$').hasMatch(key)) {
        displaySite = 'Vimeo';
        uri = Uri.https('vimeo.com', '/$key');
      } else {
        continue;
      }
      if (!seen.add(uri.toString())) continue;
      final name = item['name'];
      videos.add(MovieInfoVideo(
        name: name is String && name.trim().isNotEmpty ? name.trim() : type,
        type: type,
        site: displaySite,
        uri: uri,
        youtubeKey: youtubeKey,
        isOfficial: item['official'] == true,
      ));
    }
    // Keep the source order within trailers and within other videos.
    return [
      ...videos.where((item) => item.type.toLowerCase() == 'trailer'),
      ...videos.where((item) => item.type.toLowerCase() != 'trailer'),
    ];
  }
}
