import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'movie_details_screen.dart';

const String apiKey = '30e125ca82f6e71828b3a30c47ea67c2';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w780';
const String backdropBase = 'https://image.tmdb.org/t/p/w1280';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  bool hasConnection = true;
  final _apiCache = <String, List<dynamic>>{};
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  final Color _netflixRed = Color(0xFFE50914);
  final Color _netflixBlack = Color(0xFF141414);
  final Color _netflixDarkGray = Color(0xFF2D2D2D);
  final Color _netflixWhite = Colors.white;

  List<dynamic> trendingMovies = [];
  List<dynamic> popularMovies = [];
  List<dynamic> nowPlayingMovies = [];
  List<dynamic> topRatedMovies = [];
  List<dynamic> upcomingMovies = [];
  List<dynamic> actionMovies = [];
  List<dynamic> comedyMovies = [];
  List<dynamic> dramaMovies = [];
  List<dynamic> horrorMovies = [];
  List<dynamic> romanceMovies = [];
  List<dynamic> scifiMovies = [];
  List<dynamic> thrillerMovies = [];
  List<dynamic> adventureMovies = [];
  List<dynamic> animationMovies = [];
  List<dynamic> fantasyMovies = [];
  List<dynamic> mysteryMovies = [];
  List<dynamic> crimeMovies = [];
  List<dynamic> documentaryMovies = [];
  List<dynamic> familyMovies = [];
  List<dynamic> historyMovies = [];
  List<dynamic> hollywoodSeries = [];
  List<dynamic> warMovies = [];
  List<dynamic> westernMovies = [];
  List<dynamic> tvMovies = [];
  List<dynamic> bollywoodMovies = [];
  List<dynamic> superheroMovies = [];
  List<dynamic> martialArtsMovies = [];
  List<dynamic> spyMovies = [];
  List<dynamic> heistMovies = [];
  List<dynamic> disasterMovies = [];
  List<dynamic> hollywoodMovies = [];
  List<dynamic> politicalMovies = [];
  List<dynamic> courtroomMovies = [];
  List<dynamic> noirMovies = [];
  List<dynamic> slasherMovies = [];
  List<dynamic> paranormalMovies = [];
  List<dynamic> generalSeries = [];
  List<dynamic> indieMovies = [];
  List<dynamic> cultMovies = [];
  List<dynamic> awardWinningMovies = [];

  final List<Color> _categoryColors = [
    Color(0xFFFF006E),
    Color(0xFF8338EC),
    Color(0xFF3A86FF),
    Color(0xFFFB5607),
    Color(0xFFFFBE0B),
    Color(0xFF06D6A0),
    Color(0xFFEF476F),
    Color(0xFF118AB2),
    Color(0xFF7209B7),
    Color(0xFFF15BB5),
    Color(0xFF00BBF9),
    Color(0xFF00F5D4),
    Color(0xFFFF0054),
    Color(0xFF9B5DE5),
    Color(0xFFFEE440),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF1A936F),
    Color(0xFF114B5F),
    Color(0xFFC44536),
    Color(0xFFE56B70),
    Color(0xFF5F0F40),
    Color(0xFF9A031E),
    Color(0xFFFB8B24),
    Color(0xFF560BAD),
    Color(0xFFB5179E),
    Color(0xFFF72585),
    Color(0xFF480CA8),
    Color(0xFF4CC9F0),
    Color(0xFF4361EE),
    Color(0xFF38B000),
    Color(0xFF70E000),
    Color(0xFF9EF01A),
    Color(0xFFCCFF33),
    Color(0xFF80ED99),
    Color(0xFF57CC99),
    Color(0xFF22577A),
    Color(0xFF38A3A5),
    Color(0xFFF77F00),
    Color(0xFFD62828),
  ];

  final List<String> _categoryTitles = [
    '🔥 Trending Now',
    '🎬 Now in Cinemas',
    '🌟 Most Popular',
    '⭐ Top Rated',
    '🚀 Coming Soon',
    '💥 Action Packed',
    '😂 Comedy Gold',
    '🎭 Powerful Drama',
    '👻 Horror Thrills',
    '💖 Romantic Tales',
    '👽 Sci-Fi Worlds',
    '🔪 Edge Thrillers',
    '🏔️ Epic Adventures',
    '🐰 Animated Magic',
    '🧙‍♂️ Fantasy Realms',
    '🕵️ Mystery Cases',
    '🔫 Crime Stories',
    '📹 Real Documentaries',
    '👨‍👩‍👧‍👦 Family Fun',
    '📜 Historical Epics',
    '🎬 Hollywood Series',
    '⚔️ War Stories',
    '🤠 Western Classics',
    '📺 TV Movies',
    '🎭 Bollywood Hits',
    '🦸 Superhero Saga',
    '🥋 Martial Arts',
    '🕶️ Spy Thrillers',
    '💰 Heist Capers',
    '🌪️ Disaster Flicks',
    '🎬 Hollywood Movies',
    '🏛️ Political Thrills',
    '⚖️ Courtroom Drama',
    '🎩 Film Noir',
    '🔪 Slasher Horror',
    '👻 Paranormal Tales',
    '📺 General Series',
    '🎨 Indie Gems',
    '🤘 Cult Classics',
    '🏆 Award Winners',
  ];

  @override
  void initState() {
    super.initState();

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
    );

    _setupConnectivityMonitoring();
    _loadEssentialContent();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _transitionController.dispose();
    super.dispose();
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final connected = result != ConnectivityResult.none;
        if (connected != hasConnection) {
          _handleConnectionChange(connected);
        }
      },
    );
  }

  void _handleConnectionChange(bool connected) async {
    if (mounted) {
      setState(() {
        hasConnection = connected;
      });

      if (connected) {
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          _loadEssentialContent();
        }
      }
    }
  }

  Future<void> _loadEssentialContent() async {
    if (!hasConnection) return;

    _transitionController.reverse();
    setState(() => isLoading = true);

    try {
      final essentialResponses = await Future.wait([
        _fetchCachedCategory('trending'),
        _fetchCachedCategory('popular'),
        _fetchCachedCategory('now_playing'),
      ]);

      if (mounted) {
        setState(() {
          trendingMovies = essentialResponses[0];
          popularMovies = essentialResponses[1];
          nowPlayingMovies = essentialResponses[2];
          isLoading = false;
        });
        _transitionController.forward();
      }

      _loadBackgroundContent();
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _transitionController.forward();
      }
    }
  }

  Future<void> _loadBackgroundContent() async {
    if (!hasConnection) return;

    final backgroundCategories = [
      'top_rated',
      'upcoming',
      'action',
      'comedy',
      'drama',
      'horror',
      'romance',
      'scifi',
      'thriller',
      'adventure',
      'animation',
      'fantasy',
      'mystery',
      'crime',
      'documentary',
      'family',
      'history',
      'hollywood_series',
      'war',
      'western',
      'tv',
      'bollywood',
      'superhero',
      'martial_arts',
      'spy',
      'heist',
      'disaster',
      'hollywood_movies',
      'political',
      'courtroom',
      'noir',
      'slasher',
      'paranormal',
      'general_series',
      'indie',
      'cult',
      'award_winning'
    ];

    for (final category in backgroundCategories) {
      if (!mounted || !hasConnection) break;

      try {
        final movies = await _fetchCachedCategory(category);
        if (mounted && movies.isNotEmpty) {
          setState(() {
            _updateMovieList(category, movies);
          });
        }
      } catch (e) {}
    }
  }

  Future<List<dynamic>> _fetchCachedCategory(String category) async {
    final cacheKey = category;

    if (_apiCache.containsKey(cacheKey)) {
      return _apiCache[cacheKey]!;
    }

    try {
      final response = await http.get(Uri.parse(_getCategoryUrl(category)));

      if (response.statusCode == 200) {
        final movies = _parseMovies(response);
        _apiCache[cacheKey] = movies;
        return movies;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  String _getCategoryUrl(String category) {
    final urls = {
      'trending': '$baseUrl/trending/movie/day?api_key=$apiKey',
      'popular': '$baseUrl/movie/popular?api_key=$apiKey',
      'now_playing': '$baseUrl/movie/now_playing?api_key=$apiKey',
      'top_rated': '$baseUrl/movie/top_rated?api_key=$apiKey',
      'upcoming': '$baseUrl/movie/upcoming?api_key=$apiKey',
      'action': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=28',
      'comedy': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=35',
      'drama': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=18',
      'horror': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=27',
      'romance': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10749',
      'scifi': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=878',
      'thriller': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=53',
      'adventure': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=12',
      'animation': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=16',
      'fantasy': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=14',
      'mystery': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=9648',
      'crime': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=80',
      'documentary': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=99',
      'family': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10751',
      'history': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=36',
      'hollywood_series': '$baseUrl/discover/tv?api_key=$apiKey&with_networks=49',
      'war': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10752',
      'western': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=37',
      'tv': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10770',
      'bollywood':
          '$baseUrl/discover/movie?api_key=$apiKey&with_original_language=hi',
      'superhero': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9715',
      'martial_arts':
          '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=14440',
      'spy': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10702',
      'heist': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10496',
      'disaster': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9747',
      'hollywood_movies': '$baseUrl/discover/movie?api_key=$apiKey&with_original_language=en&region=US',
      'political': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9717',
      'courtroom':
          '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10534',
      'noir': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10495',
      'slasher': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10504',
      'paranormal':
          '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10508',
      'general_series': '$baseUrl/discover/tv?api_key=$apiKey',
      'indie': '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=9749',
      'cult':
          '$baseUrl/discover/movie?api_key=$apiKey&vote_average.gte=7.5&vote_count.gte=1000',
      'award_winning':
          '$baseUrl/discover/movie?api_key=$apiKey&with_keywords=10511',
    };

    return urls[category] ?? '';
  }

  void _updateMovieList(String category, List<dynamic> movies) {
    switch (category) {
      case 'trending':
        trendingMovies = movies;
        break;
      case 'popular':
        popularMovies = movies;
        break;
      case 'now_playing':
        nowPlayingMovies = movies;
        break;
      case 'top_rated':
        topRatedMovies = movies;
        break;
      case 'upcoming':
        upcomingMovies = movies;
        break;
      case 'action':
        actionMovies = movies;
        break;
      case 'comedy':
        comedyMovies = movies;
        break;
      case 'drama':
        dramaMovies = movies;
        break;
      case 'horror':
        horrorMovies = movies;
        break;
      case 'romance':
        romanceMovies = movies;
        break;
      case 'scifi':
        scifiMovies = movies;
        break;
      case 'thriller':
        thrillerMovies = movies;
        break;
      case 'adventure':
        adventureMovies = movies;
        break;
      case 'animation':
        animationMovies = movies;
        break;
      case 'fantasy':
        fantasyMovies = movies;
        break;
      case 'mystery':
        mysteryMovies = movies;
        break;
      case 'crime':
        crimeMovies = movies;
        break;
      case 'documentary':
        documentaryMovies = movies;
        break;
      case 'family':
        familyMovies = movies;
        break;
      case 'history':
        historyMovies = movies;
        break;
      case 'hollywood_series':
        hollywoodSeries = movies;
        break;
      case 'war':
        warMovies = movies;
        break;
      case 'western':
        westernMovies = movies;
        break;
      case 'tv':
        tvMovies = movies;
        break;
      case 'bollywood':
        bollywoodMovies = movies;
        break;
      case 'superhero':
        superheroMovies = movies;
        break;
      case 'martial_arts':
        martialArtsMovies = movies;
        break;
      case 'spy':
        spyMovies = movies;
        break;
      case 'heist':
        heistMovies = movies;
        break;
      case 'disaster':
        disasterMovies = movies;
        break;
      case 'hollywood_movies':
        hollywoodMovies = movies;
        break;
      case 'political':
        politicalMovies = movies;
        break;
      case 'courtroom':
        courtroomMovies = movies;
        break;
      case 'noir':
        noirMovies = movies;
        break;
      case 'slasher':
        slasherMovies = movies;
        break;
      case 'paranormal':
        paranormalMovies = movies;
        break;
      case 'general_series':
        generalSeries = movies;
        break;
      case 'indie':
        indieMovies = movies;
        break;
      case 'cult':
        cultMovies = movies;
        break;
      case 'award_winning':
        awardWinningMovies = movies;
        break;
    }
  }

  List<dynamic> _parseMovies(http.Response response) {
    try {
      final data = json.decode(response.body);
      return (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      return [];
    }
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _loadEssentialContent,
      backgroundColor: _netflixBlack,
      color: _netflixRed,
      child: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: isLoading
                ? _buildOptimizedLoadingScreen()
                : CustomScrollView(slivers: _buildSliverList()),
          ),
          if (!hasConnection) _buildNoConnectionBanner(),
        ],
      ),
    );
  }

  Widget _buildNoConnectionBanner() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
      left: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_netflixRed, Colors.orange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connection lost. Please check your internet and try again.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSliverList() {
    final slivers = <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: 0)),
      SliverToBoxAdapter(child: _buildCarousel()),
      SliverToBoxAdapter(child: SizedBox(height: 30)),
    ];

    for (int i = 0; i < _categoryTitles.length; i++) {
      final section = _buildMovieSectionIfReady(i);
      if (section != null) {
        slivers.add(section);
      }
    }

    slivers.add(SliverToBoxAdapter(child: SizedBox(height: 40)));
    return slivers;
  }

  Widget? _buildMovieSectionIfReady(int categoryIndex) {
    final movies = _getMoviesForCategory(categoryIndex);
    if (movies.isEmpty) return null;

    return SliverToBoxAdapter(
      child: _buildMovieSection(categoryIndex),
    );
  }

  Widget _buildOptimizedLoadingScreen() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCarouselShimmer()),
        SliverToBoxAdapter(child: _buildSectionShimmer()),
        SliverToBoxAdapter(child: _buildSectionShimmer()),
        SliverToBoxAdapter(child: _buildSectionShimmer()),
      ],
    );
  }

  Widget _buildCarouselShimmer() {
    return Container(
      height: 320,
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildSectionShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          width: 200,
          margin: EdgeInsets.all(16),
          color: Colors.grey[800],
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: 5,
            itemBuilder: (context, index) => Container(
              width: 140,
              margin: EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 170,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(height: 16, width: 120, color: Colors.grey[800]),
                  SizedBox(height: 6),
                  Container(height: 12, width: 80, color: Colors.grey[800]),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCarousel() {
    if (trendingMovies.isEmpty) return SizedBox(height: 300);

    return CarouselSlider.builder(
      itemCount: trendingMovies.length,
      itemBuilder: (context, index, _) {
        final movie = trendingMovies[index];
        final imageUrl = movie['backdrop_path'] != null
            ? '$backdropBase${movie['backdrop_path']}'
            : null;

        return GestureDetector(
          onTap: () => _navigateToDetails(movie),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_netflixDarkGray, Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFE50914))),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_netflixDarkGray, Colors.black],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.movie_rounded,
                          color: _netflixWhite.withOpacity(0.3), size: 60),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          _netflixBlack.withOpacity(0.95),
                          Colors.transparent,
                          Colors.transparent,
                          _netflixBlack.withOpacity(0.4),
                        ],
                        stops: [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_netflixRed, Colors.orange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.yellow[700], size: 14),
                          SizedBox(width: 4),
                          Text(
                            'TRENDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 20,
                    right: 20,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 500),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.yellow[700],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded,
                                        color: Colors.black, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      ((movie['vote_average'] ?? 0.0) as num)
                                          .toStringAsFixed(1),
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getYearFromDate(movie['release_date']),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            movie['title'] ?? 'Unknown Title',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black)
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Text(
                            movie['overview'] ?? '',
                            style: TextStyle(
                                color: _netflixWhite.withOpacity(0.9),
                                fontSize: 12,
                                height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      options: CarouselOptions(
        height: 320,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.92,
        aspectRatio: 16 / 9,
        autoPlayInterval: Duration(seconds: 6),
        autoPlayAnimationDuration: Duration(milliseconds: 800),
      ),
    );
  }

  Widget _buildMovieSection(int categoryIndex) {
    final title = _categoryTitles[categoryIndex];
    final movies = _getMoviesForCategory(categoryIndex);
    final accentColor = _categoryColors[categoryIndex % _categoryColors.length];

    if (movies.isEmpty) return SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.15),
                accentColor.withOpacity(0.05)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Text(_getEmoji(title), style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getTitleWithoutEmoji(title),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              GestureDetector(
                onTap: () => _onViewAllPressed(title, movies),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, _darkenColor(accentColor, 0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (context, index) =>
                _buildMovieCard(movies[index], accentColor),
          ),
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMovieCard(dynamic movie, Color accentColor) {
    final posterPath = movie['poster_path'];
    final imageUrl = posterPath != null ? '$imageBase$posterPath' : null;
    final rating = ((movie['vote_average'] ?? 0.0) as num).toDouble();

    return GestureDetector(
      onTap: () => _navigateToDetails(movie),
      child: Container(
        width: 140,
        margin: EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 15,
                      offset: Offset(0, 8)),
                  BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 0)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_netflixDarkGray, Colors.black],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFE50914))),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_netflixDarkGray, Colors.black],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.movie_rounded,
                            color: _netflixWhite.withOpacity(0.3), size: 40),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.yellow[700], size: 12),
                            SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: Text(
                movie['title'] ?? 'Unknown Title',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 2),
            SizedBox(
              height: 14,
              child: Row(
                children: [
                  Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: accentColor, shape: BoxShape.circle)),
                  SizedBox(width: 6),
                  Text(
                    _getYearFromDate(movie['release_date']),
                    style: TextStyle(
                        color: _netflixWhite.withOpacity(0.7), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getMoviesForCategory(int index) {
    switch (index) {
      case 0:
        return trendingMovies;
      case 1:
        return nowPlayingMovies;
      case 2:
        return popularMovies;
      case 3:
        return topRatedMovies;
      case 4:
        return upcomingMovies;
      case 5:
        return actionMovies;
      case 6:
        return comedyMovies;
      case 7:
        return dramaMovies;
      case 8:
        return horrorMovies;
      case 9:
        return romanceMovies;
      case 10:
        return scifiMovies;
      case 11:
        return thrillerMovies;
      case 12:
        return adventureMovies;
      case 13:
        return animationMovies;
      case 14:
        return fantasyMovies;
      case 15:
        return mysteryMovies;
      case 16:
        return crimeMovies;
      case 17:
        return documentaryMovies;
      case 18:
        return familyMovies;
      case 19:
        return historyMovies;
      case 20:
        return hollywoodSeries;
      case 21:
        return warMovies;
      case 22:
        return westernMovies;
      case 23:
        return tvMovies;
      case 24:
        return bollywoodMovies;
      case 25:
        return superheroMovies;
      case 26:
        return martialArtsMovies;
      case 27:
        return spyMovies;
      case 28:
        return heistMovies;
      case 29:
        return disasterMovies;
      case 30:
        return hollywoodMovies;
      case 31:
        return politicalMovies;
      case 32:
        return courtroomMovies;
      case 33:
        return noirMovies;
      case 34:
        return slasherMovies;
      case 35:
        return paranormalMovies;
      case 36:
        return generalSeries;
      case 37:
        return indieMovies;
      case 38:
        return cultMovies;
      case 39:
        return awardWinningMovies;
      default:
        return [];
    }
  }

  void _onViewAllPressed(String category, List<dynamic> movies) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _netflixDarkGray,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _categoryColors[category.hashCode % _categoryColors.length],
                    Colors.purple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getFirstWord(category),
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: movies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_creation_outlined,
                          color: Colors.white54, size: 50),
                      SizedBox(height: 10),
                      Text('No movies found',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    final movie = movies[index];
                    return _buildGridMovieCard(
                        movie,
                        _categoryColors[
                            category.hashCode % _categoryColors.length]);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMovieCard(dynamic movie, Color accentColor) {
    final posterPath = movie['poster_path'];
    final imageUrl = posterPath != null ? '$imageBase$posterPath' : null;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _navigateToDetails(movie);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(
                  color: _netflixDarkGray,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFE50914))),
                ),
                errorWidget: (context, url, error) => Container(
                  color: _netflixDarkGray,
                  child: Icon(Icons.movie_rounded,
                      color: _netflixWhite.withOpacity(0.3), size: 30),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['title'] ?? 'Unknown',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.yellow[700], size: 12),
                        SizedBox(width: 4),
                        Text(
                          ((movie['vote_average'] ?? 0.0) as num)
                              .toStringAsFixed(1),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MovieDetailsScreen(movie: movie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }

  String _getFirstWord(String text) {
    final words = text.replaceAll(RegExp(r'[^\w\s]'), '').trim().split(' ');
    return words.isNotEmpty ? words.first : 'Movie';
  }

  String _getEmoji(String title) {
    final emojiEndIndex = title.indexOf(' ');
    return emojiEndIndex != -1 ? title.substring(0, emojiEndIndex) : title;
  }

  String _getTitleWithoutEmoji(String title) {
    final emojiEndIndex = title.indexOf(' ');
    return emojiEndIndex != -1 ? title.substring(emojiEndIndex + 1) : title;
  }

  Color _darkenColor(Color color, double factor) {
    assert(factor >= 0 && factor <= 1);
    return Color.fromARGB(
      color.alpha,
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
    );
  }

  String _getYearFromDate(String? date) {
    if (date == null || date.isEmpty) return 'Coming Soon';
    try {
      return DateTime.parse(date).year.toString();
    } catch (e) {
      return 'Coming Soon';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _netflixBlack,
      body: _buildHomeContent(),
    );
  }
}