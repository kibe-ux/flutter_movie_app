import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'movie_details_screen.dart';
import '../utils/my_list.dart';
import '../utils/cinema_palette.dart';
import '../services/ad_service.dart';
import '../services/catalogue_json_client.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/movie_hub_banner_ad.dart';
import '../utils/movie_download_availability.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';

// Explore Screen
class ExploreScreen extends StatefulWidget {
  const ExploreScreen(
      {super.key, required Set<int> myListIds}); // REMOVED: myListIds parameter

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> genres = [];
  List<dynamic> movies = [];
  String? selectedGenreId;
  String _mediaType = 'movie';
  bool isLoading = true;
  String searchQuery = '';
  String? _error;
  int _requestGeneration = 0;
  Timer? _searchDebounce;
  final _searchController = TextEditingController();
  final _catalogue = CatalogueJsonClient();

  bool get _isTv => _mediaType == 'tv';

  @override
  void initState() {
    super.initState();
    fetchGenres();
  }

  Future<Map<String, dynamic>> _getData(String path,
      {Map<String, String> parameters = const {}, bool refresh = false}) async {
    final uri = Uri.https('api.themoviedb.org', '/3/$path', {
      'api_key': apiKey,
      'language': 'en-US',
      ...parameters,
    });
    return _catalogue.get(uri, refresh: refresh);
  }

  Future<void> fetchGenres({bool refresh = false}) async {
    _searchDebounce?.cancel();
    final generation = ++_requestGeneration;
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final data = await _getData('genre/$_mediaType/list', refresh: refresh);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        genres = [
          ...?data['genres'] as List?,
          if (!_isTv) {'id': '878,12', 'name': 'Sci-Fi & Adventure'},
        ];
        if (!genres.any((genre) => genre['id'].toString() == selectedGenreId)) {
          selectedGenreId =
              genres.isEmpty ? null : genres.first['id'].toString();
        }
        isLoading = false;
      });
      if (searchQuery.isNotEmpty) {
        await searchMovies(searchQuery, refresh: refresh);
      } else if (selectedGenreId != null) {
        await fetchMoviesByGenre(selectedGenreId!, refresh: refresh);
      }
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        isLoading = false;
        _error = 'Unable to load genres. Pull down to retry.';
      });
    }
  }

  Future<void> fetchMoviesByGenre(String genreId,
      {bool refresh = false}) async {
    selectedGenreId = genreId;
    await _loadTitles('discover/$_mediaType', {'with_genres': genreId},
        refresh: refresh);
  }

  Future<void> _loadTitles(String path, Map<String, String> parameters,
      {bool refresh = false}) async {
    final generation = ++_requestGeneration;
    final mediaType = _mediaType;
    setState(() {
      movies = [];
      isLoading = true;
      _error = null;
    });
    try {
      final data =
          await _getData(path, parameters: parameters, refresh: refresh);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        movies = filterReleasedMovies(data['results'])
            .map((item) => {...item, 'media_type': mediaType})
            .toList();
        isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        isLoading = false;
        _error = 'Unable to load titles. Pull down to retry.';
      });
    }
  }

  Future<void> searchMovies(String query, {bool refresh = false}) async {
    if (query.isEmpty) {
      if (selectedGenreId != null) {
        await fetchMoviesByGenre(selectedGenreId!, refresh: refresh);
      } else {
        await fetchGenres(refresh: refresh);
      }
      return;
    }
    await _loadTitles('search/$_mediaType', {'query': query}, refresh: refresh);
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    ++_requestGeneration;
    searchQuery = query;
    setState(() {
      isLoading = true;
      _error = null;
    });
    if (query.isEmpty) {
      searchMovies(query);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) searchMovies(query);
    });
  }

  void _selectGenre(String genreId) {
    _searchDebounce?.cancel();
    _searchController.clear();
    searchQuery = '';
    fetchMoviesByGenre(genreId);
  }

  void _selectMediaType(String mediaType) {
    if (_mediaType == mediaType) return;
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _mediaType = mediaType;
      searchQuery = '';
      selectedGenreId = null;
      genres = [];
      movies = [];
    });
    fetchGenres();
  }

  Widget _buildMediaTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'movie', label: Text('Movies')),
            ButtonSegment(value: 'tv', label: Text('TV Shows')),
          ],
          selected: {_mediaType},
          onSelectionChanged: (selection) => _selectMediaType(selection.single),
          style: SegmentedButton.styleFrom(
            foregroundColor: CinemaPalette.ivory,
            backgroundColor: CinemaPalette.surface,
            selectedForegroundColor: CinemaPalette.background,
            selectedBackgroundColor: CinemaPalette.gold,
          ),
        ),
      ),
    );
  }

  Widget _buildGenresSection() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = genre['id'].toString() == selectedGenreId;

          return GestureDetector(
            onTap: () => _selectGenre(genre['id'].toString()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? CinemaPalette.gold : CinemaPalette.surface,
                border: Border.all(
                  color: CinemaPalette.gold.withValues(
                    alpha: isSelected ? 1 : 0.16,
                  ),
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: CinemaPalette.gold.withValues(alpha: 0.18),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  genre['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? CinemaPalette.background
                        : CinemaPalette.ivory,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoviesSliverGrid() {
    if (isLoading) {
      return _buildSkeletonSliverGrid();
    }

    if (movies.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.movie_filter,
                  color: CinemaPalette.gold,
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  _error ??
                      'No ${_isTv ? 'TV shows' : 'movies'} found for this genre/search.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: CinemaPalette.muted, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final movie = movies[index];
            final imageUrl = movie['poster_path'] != null
                ? '$imageBase${movie['poster_path']}'
                : null;
            final movieId = movie['id'] ?? 0;
            final isInMyList = MyList().contains(movieId);

            return GestureDetector(
              onTap: () {
                AdService().onMoviePosterTap(() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MovieDetailsScreen(movie: movie)),
                  );
                },
                    isActive: () =>
                        mounted &&
                        context.mounted &&
                        (ModalRoute.of(context)?.isCurrent ?? true));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: CinemaPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeNetworkImage(
                      imageUrl: imageUrl,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 28,
                      left: 8,
                      right: 8,
                      child: Text(
                        movie['title'] ?? movie['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: CinemaPalette.ivory,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            MyList().toggle(movieId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  MyList().contains(movieId)
                                      ? 'Added to My List'
                                      : 'Removed from My List',
                                  style: const TextStyle(
                                      color: CinemaPalette.ivory),
                                ),
                                backgroundColor: CinemaPalette.wine,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isInMyList ? Icons.bookmark : Icons.bookmark_border,
                            color: isInMyList
                                ? CinemaPalette.gold
                                : CinemaPalette.ivory,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: CinemaPalette.gold, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${movie['vote_average']?.toStringAsFixed(1) ?? 'N/A'}',
                              style: const TextStyle(
                                color: CinemaPalette.ivory,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: movies.length,
        ),
      ),
    );
  }

  Widget _buildSkeletonSliverGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _MovieSkeletonCard(),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: CinemaPalette.ivory),
        cursorColor: CinemaPalette.gold,
        decoration: InputDecoration(
          hintText: _isTv ? 'Search TV shows...' : 'Search movies...',
          hintStyle: const TextStyle(color: CinemaPalette.muted),
          filled: true,
          fillColor: CinemaPalette.surface,
          prefixIcon: const Icon(Icons.search, color: CinemaPalette.muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: CinemaPalette.gold.withValues(alpha: 0.16),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: CinemaPalette.gold),
          ),
        ),
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinemaPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: CinemaPalette.ivory,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: CinemaPalette.appBarGradient,
          ),
        ),
        title: const Text(
          'Explore',
          style: TextStyle(
            color: CinemaPalette.appBarText,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (!isLoading && movies.isNotEmpty)
            const MovieHubBannerAd(placement: 'explore'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await fetchGenres(refresh: true);
              },
              color: CinemaPalette.gold,
              backgroundColor: CinemaPalette.surface,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMediaTabs(),
                        _buildSearchBar(),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Genres',
                            style: TextStyle(
                              color: CinemaPalette.ivory,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildGenresSection(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  _buildMoviesSliverGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ++_requestGeneration;
    _searchDebounce?.cancel();
    _searchController.dispose();
    _catalogue.close();
    super.dispose();
  }
}

class _MovieSkeletonCard extends StatefulWidget {
  const _MovieSkeletonCard();

  @override
  State<_MovieSkeletonCard> createState() => _MovieSkeletonCardState();
}

class _MovieSkeletonCardState extends State<_MovieSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + (_controller.value * 2), -0.3),
            end: Alignment(_controller.value * 2, 0.3),
            colors: const [
              CinemaPalette.surface,
              CinemaPalette.wine,
              CinemaPalette.surface,
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
