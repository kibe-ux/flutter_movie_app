class HomeCategory {
  const HomeCategory(this.name, this.endpoint, [this.filters = const {}]);

  final String name;
  final String endpoint;
  final Map<String, String> filters;

  bool get isTv => endpoint.split('/').contains('tv');

  Uri uri(String apiKey, {int page = 1, DateTime? now}) {
    return Uri.https('api.themoviedb.org', '/3/$endpoint', {
      'api_key': apiKey,
      'language': 'en-US',
      ...filters,
      if (name == 'Latest Movies')
        'release_date.lte':
            (now ?? DateTime.now()).toIso8601String().split('T').first,
      'page': '$page',
    });
  }
}

const homeCategories = <HomeCategory>[
  HomeCategory('Trending Today', 'trending/movie/day'),
  HomeCategory('Now Playing', 'movie/now_playing'),
  HomeCategory('Latest Movies', 'discover/movie', {'sort_by': 'release_date.desc'}),
  HomeCategory('Top Rated', 'movie/top_rated'),
  HomeCategory('Popular Movies', 'movie/popular'),
  HomeCategory(
      'Box Office Hits', 'discover/movie', {'sort_by': 'revenue.desc'}),
  HomeCategory('Horror & Mystery', 'discover/movie',
      {'with_genres': '27,9648', 'sort_by': 'popularity.desc'}),
  HomeCategory('Action & Thriller', 'discover/movie',
      {'with_genres': '28,53', 'sort_by': 'popularity.desc'}),
  HomeCategory('Sci-Fi & Adventure', 'discover/movie',
      {'with_genres': '878,12', 'sort_by': 'popularity.desc'}),
  HomeCategory('Comedy', 'discover/movie',
      {'with_genres': '35', 'sort_by': 'popularity.desc'}),
  HomeCategory('Crime & Thriller', 'discover/movie',
      {'with_genres': '80,53', 'sort_by': 'popularity.desc'}),
  HomeCategory('Family & Kids', 'discover/movie',
      {'with_genres': '10751', 'sort_by': 'popularity.desc'}),
  HomeCategory('Animation & Anime', 'discover/movie',
      {'with_genres': '16', 'sort_by': 'popularity.desc'}),
  HomeCategory('Popular TV Shows', 'tv/popular'),
  HomeCategory('Trending TV Today', 'trending/tv/day'),
  HomeCategory('Trending TV This Week', 'trending/tv/week'),
  HomeCategory('Top Rated TV Shows', 'tv/top_rated'),
  HomeCategory('Airing Today', 'tv/airing_today'),
  HomeCategory('On the Air', 'tv/on_the_air'),
  HomeCategory('Action & Adventure TV', 'discover/tv',
      {'with_genres': '10759', 'sort_by': 'popularity.desc'}),
  HomeCategory('Comedy TV', 'discover/tv',
      {'with_genres': '35', 'sort_by': 'popularity.desc'}),
  HomeCategory('Crime TV', 'discover/tv',
      {'with_genres': '80', 'sort_by': 'popularity.desc'}),
  HomeCategory('Drama TV', 'discover/tv',
      {'with_genres': '18', 'sort_by': 'popularity.desc'}),
  HomeCategory('Animation TV', 'discover/tv',
      {'with_genres': '16', 'sort_by': 'popularity.desc'}),
  HomeCategory('Documentary TV', 'discover/tv',
      {'with_genres': '99', 'sort_by': 'popularity.desc'}),
  HomeCategory('Drama & Mystery TV', 'discover/tv',
      {'with_genres': '18,9648', 'sort_by': 'popularity.desc'}),
  HomeCategory('Sci-Fi & Fantasy TV', 'discover/tv',
      {'with_genres': '10765', 'sort_by': 'popularity.desc'}),
];

final homeCategoriesByName = {
  for (final category in homeCategories) category.name: category,
};
