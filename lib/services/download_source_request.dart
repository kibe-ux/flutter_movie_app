import 'queued_download_source.dart';
import 'wambesha_api_service.dart';

/// Serializable source identity; Firebase credentials are obtained only at use.
class DownloadSourceRequest {
  DownloadSourceRequest(
      {required this.original,
      required this.selectedUrl,
      required this.tmdbId,
      this.titleRef,
      this.title,
      this.releaseDate,
      this.season,
      this.episode});
  WambeshaSources original;
  String selectedUrl;
  final int tmdbId;
  final String? titleRef;
  final String? title;
  final String? releaseDate;
  final int? season;
  final int? episode;

  Future<String> resolve() async {
    var refreshed = original;
    final url = await queuedDownloadSource(
        original: original,
        selectedUrl: selectedUrl,
        reload: () async {
          final api = WambeshaApiService();
          try {
            refreshed = season != null && episode != null
                ? await api.episodeSources(
                    seriesTmdbId: tmdbId,
                    seriesRef: titleRef,
                    seriesTitle: title,
                    releaseDate: releaseDate,
                    season: season!,
                    episode: episode!)
                : await api.movieSources(
                    tmdbId: tmdbId,
                    titleRef: titleRef,
                    title: title,
                    releaseDate: releaseDate);
            return refreshed;
          } finally {
            api.dispose();
          }
        });
    original = refreshed;
    selectedUrl = url;
    return url;
  }

  Map<String, dynamic> toJson() => {
        'sources': original.sources,
        'selectedUrl': selectedUrl,
        'tmdbId': tmdbId,
        'titleRef': titleRef,
        'title': title,
        'releaseDate': releaseDate,
        'season': season,
        'episode': episode
      };
  factory DownloadSourceRequest.fromJson(Map<String, dynamic> json) =>
      DownloadSourceRequest(
          original: WambeshaSources.fromJson({'sources': json['sources']}),
          selectedUrl: json['selectedUrl'] as String,
          tmdbId: json['tmdbId'] as int,
          titleRef: json['titleRef'] as String?,
          title: json['title'] as String?,
          releaseDate: json['releaseDate'] as String?,
          season: json['season'] as int?,
          episode: json['episode'] as int?);
}
