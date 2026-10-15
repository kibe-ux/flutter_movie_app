class Films365ListEnvelope {
  const Films365ListEnvelope({
    required this.status,
    required this.page,
    required this.resultsCount,
    required this.totalPages,
    required this.totalResults,
    required this.results,
  });

  final String status;
  final int page;
  final int resultsCount;
  final int totalPages;
  final int totalResults;
  final List<Map<String, dynamic>> results;

  factory Films365ListEnvelope.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    return Films365ListEnvelope(
      status: json['status'] is String ? json['status'] as String : '',
      page: json['page'] is num ? (json['page'] as num).toInt() : 0,
      resultsCount: json['results_count'] is num
          ? (json['results_count'] as num).toInt()
          : 0,
      totalPages: json['total_pages'] is num
          ? (json['total_pages'] as num).toInt()
          : 0,
      totalResults: json['total_results'] is num
          ? (json['total_results'] as num).toInt()
          : 0,
      results: rawResults is List
          ? rawResults
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList()
          : <Map<String, dynamic>>[],
    );
  }
}

class Films365SearchEnvelope {
  const Films365SearchEnvelope({
    required this.all,
    required this.movies,
    required this.tvs,
    required this.totalCount,
  });

  final List<Map<String, dynamic>> all;
  final List<Map<String, dynamic>> movies;
  final List<Map<String, dynamic>> tvs;
  final int totalCount;

  factory Films365SearchEnvelope.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    final results = rawResults is Map
        ? rawResults.cast<String, dynamic>()
        : <String, dynamic>{};
    final rawAll = results['all'];
    final rawMovies = results['movies'];
    final rawTvs = results['tvs'];

    return Films365SearchEnvelope(
      all: rawAll is List
          ? rawAll
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList()
          : <Map<String, dynamic>>[],
      movies: rawMovies is List
          ? rawMovies
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList()
          : <Map<String, dynamic>>[],
      tvs: rawTvs is List
          ? rawTvs
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList()
          : <Map<String, dynamic>>[],
      totalCount: json['totalCount'] is num
          ? (json['totalCount'] as num).toInt()
          : 0,
    );
  }
}

class Films365DetailsEnvelope {
  const Films365DetailsEnvelope({
    required this.status,
    required this.data,
  });

  final String status;
  final Map<String, dynamic> data;

  factory Films365DetailsEnvelope.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return Films365DetailsEnvelope(
      status: json['status'] is String ? json['status'] as String : '',
      data: rawData is Map
          ? rawData.cast<String, dynamic>()
          : <String, dynamic>{},
    );
  }
}

class Films365Item {
  const Films365Item({
    required this.id,
    required this.title,
    required this.tmdbId,
    required this.posterUrl,
    required this.genres,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.date,
    required this.type,
  });

  final String id;
  final String title;
  final int? tmdbId;
  final String? posterUrl;
  final List<String> genres;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final String? date;
  final String? type;

  factory Films365Item.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genres'];
    final rawDate = json['releaseDate'] ?? json['firstAirDate'];
    final rawVoteCount = json['voteCount'] ?? json['votesCount'];

    return Films365Item(
      id: json['id'] is String ? json['id'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      tmdbId: json['tmdbId'] is num ? (json['tmdbId'] as num).toInt() : null,
      posterUrl:
          json['posterUrl'] is String ? json['posterUrl'] as String : null,
      genres: rawGenres is List
          ? rawGenres.whereType<String>().toList()
          : <String>[],
      voteAverage: json['voteAverage'] is num
          ? (json['voteAverage'] as num).toDouble()
          : 0,
      voteCount: rawVoteCount is num ? rawVoteCount.toInt() : 0,
      popularity: json['popularity'] is num
          ? (json['popularity'] as num).toDouble()
          : 0,
      date: rawDate is String ? rawDate : null,
      type: json['type'] is String ? json['type'] as String : null,
    );
  }
}
