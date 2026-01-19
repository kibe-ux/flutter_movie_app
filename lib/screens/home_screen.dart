import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'movie_details_screen.dart';
import 'full_category_screen.dart';
import '../utils/my_list.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '9c12c3b471405cfbfeca767fa3ea8907';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w300';
const String backdropBase = 'https://image.tmdb.org/t/p/w780';

class HomeScreen extends StatefulWidget {
  final Set<int> myListIds;
  const HomeScreen({super.key, required this.myListIds});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  bool _isConnected = true;
  bool _isInitialized = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  String _currentFilter = 'All Movies';

  final List<Map<String, dynamic>> _allLoadedMovies = [];

  final Map<String, List<Map<String, dynamic>>> _movieCategories = {
    'Trending Today': [],
    'Trending This Week': [],
    'Now Playing': [],
    'Upcoming Releases': [],
    'Recently Released': [],
    'Top Rated': [],
    'Popular Movies': [],
    'Most Watched Now': [],
    'Box Office Hits': [],
    'Award Winning Movies': [],
    'Hollywood Movies': [],
    'Romance & Fantasy': [],
    'Horror & Mystery': [],
    'Action & Thriller': [],
    'Comedy': [],
    'Crime & Thriller': [],
    'Family & Kids': [],
    'Animation & Anime': [],
    'International Films': [],
    'TV Shows': [],
    'Trending TV Today': [],
    'Trending TV This Week': [],
    'Popular TV Shows': [],
    'Top Rated TV Shows': [],
    'Airing Today': [],
    'Drama & Mystery TV': [],
    'Sci-Fi & Fantasy TV': [],
  };

  final Map<String, String> _categoryUrls = {
    'Trending Today': '$baseUrl/trending/movie/day?api_key=$apiKey&language=en-US',
    'Trending This Week': '$baseUrl/trending/movie/week?api_key=$apiKey&language=en-US',
    'Now Playing': '$baseUrl/movie/now_playing?api_key=$apiKey&language=en-US',
    'Upcoming Releases': '$baseUrl/movie/upcoming?api_key=$apiKey&language=en-US',
    'Recently Released': '$baseUrl/discover/movie?api_key=$apiKey&sort_by=release_date.desc&release_date.lte=${DateTime.now().toIso8601String().split('T').first}',
    'Top Rated': '$baseUrl/movie/top_rated?api_key=$apiKey&language=en-US',
    'Popular Movies': '$baseUrl/movie/popular?api_key=$apiKey&language=en-US',
    'Most Watched Now': '$baseUrl/discover/movie?api_key=$apiKey&sort_by=popularity.desc',
    'Box Office Hits': '$baseUrl/discover/movie?api_key=$apiKey&sort_by=revenue.desc',
    'Award Winning Movies': '$baseUrl/discover/movie?api_key=$apiKey&vote_average.gte=7&sort_by=vote_count.desc',
    'Hollywood Movies': '$baseUrl/discover/movie?api_key=$apiKey&with_original_language=en&sort_by=popularity.desc',
    'Romance & Fantasy': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10749,14&sort_by=popularity.desc',
    'Horror & Mystery': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=27,9648&sort_by=popularity.desc',
    'Action & Thriller': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=28,53&sort_by=popularity.desc',
    'Comedy': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=35&sort_by=popularity.desc',
    'Crime & Thriller': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=80,53&sort_by=popularity.desc',
    'Family & Kids': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10751&sort_by=popularity.desc',
    'Animation & Anime': '$baseUrl/discover/movie?api_key=$apiKey&with_genres=16&sort_by=popularity.desc',
    'International Films': '$baseUrl/discover/movie?api_key=$apiKey&sort_by=popularity.desc&region=XX',
    'TV Shows': '$baseUrl/tv/popular?api_key=$apiKey&language=en-US',
    'Trending TV Today': '$baseUrl/trending/tv/day?api_key=$apiKey&language=en-US',
    'Trending TV This Week': '$baseUrl/trending/tv/week?api_key=$apiKey&language=en-US',
    'Popular TV Shows': '$baseUrl/tv/popular?api_key=$apiKey&language=en-US',
    'Top Rated TV Shows': '$baseUrl/tv/top_rated?api_key=$apiKey&language=en-US',
    'Airing Today': '$baseUrl/tv/airing_today?api_key=$apiKey&language=en-US',
    'Drama & Mystery TV': '$baseUrl/discover/tv?api_key=$apiKey&with_genres=18,9648&sort_by=popularity.desc',
    'Sci-Fi & Fantasy TV': '$baseUrl/discover/tv?api_key=$apiKey&with_genres=10765&sort_by=popularity.desc',
  };

  final Map<String, int> _currentPage = {};
  final Map<String, bool> _isLoadingMore = {};
  final Set<int> _usedMovieIds = {};
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  final Color _netflixBlack = const Color(0xFF141414);
  final Color _netflixRed = const Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initConnectivity();
    _initializeAds();
    await _checkAndLoadData();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isConnected = connectivityResult.isNotEmpty && 
                   connectivityResult.first != ConnectivityResult.none;
    
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final bool wasConnected = _isConnected;
    _isConnected = results.isNotEmpty && results.first != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      if (mounted) {
        setState(() {});
      }
      
      if (_isConnected && !isLoading) {
        _loadInitialData();
      }
    }
  }

  Future<void> _checkAndLoadData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }
    
    if (_isConnected) {
      await _loadInitialData();
    } else {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadInitialData() async {
    if (!_isConnected) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          _allLoadedMovies.clear();
          _usedMovieIds.clear();
          _cache.clear();
          for (var category in _movieCategories.keys) {
            _movieCategories[category]?.clear();
            _currentPage[category] = 1;
            _isLoadingMore[category] = false;
          }
        });
      }

      final essentialCategories = [
        'Trending Today',
        'Now Playing',
        'Popular Movies',
        'Top Rated',
      ];

      await Future.wait(essentialCategories
          .map((category) => _loadMore(category, reset: true)));

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      _loadRemainingCategoriesInBackground();
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadRemainingCategoriesInBackground() async {
    final remainingCategories = _movieCategories.keys
        .where((category) => ![
              'Trending Today',
              'Now Playing',
              'Popular Movies',
              'Top Rated'
            ].contains(category))
        .toList();

    for (var category in remainingCategories) {
      if (_isConnected) {
        await _loadMore(category, reset: true);
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _loadMore(String category, {bool reset = false}) async {
    if (!_isConnected) return;
    if (_isLoadingMore[category] == true) return;
    
    _isLoadingMore[category] = true;
    int page = reset ? 1 : (_currentPage[category] ?? 1) + 1;
    final cacheKey = '$category-$page';

    if (!reset && _cache.containsKey(cacheKey)) {
      _movieCategories[category]?.addAll(_cache[cacheKey]!);
      _isLoadingMore[category] = false;
      if (mounted) setState(() {});
      return;
    }

    final urlBase = _categoryUrls[category];
    if (urlBase == null) {
      _isLoadingMore[category] = false;
      if (mounted) setState(() {});
      return;
    }

    final url = '$urlBase&page=$page';
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('API request timed out'),
          );

      if (!mounted) {
        _isLoadingMore[category] = false;
        return;
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final results = (jsonData['results'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .where((m) => !_usedMovieIds.contains(m['id']))
            .toList();
        if (mounted) {
          setState(() {
            if (reset) _movieCategories[category]?.clear();
            _movieCategories[category]?.addAll(results);
            _cache[cacheKey] = results;
            for (var m in results) {
              _usedMovieIds.add(m['id']);
              if (!_allLoadedMovies.any((movie) => movie['id'] == m['id'])) {
                _allLoadedMovies.add(m);
              }
            }
            _currentPage[category] = page;
          });
        }
      }
    } finally {
      _isLoadingMore[category] = false;
    }
  }

  void _initializeAds() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isBannerAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          if (mounted) {
            setState(() {
              _isBannerAdReady = false;
            });
          }
          ad.dispose();
        },
      ),
    )..load();

    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialReady = false;
        },
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['release_date'] ?? item['first_air_date'];
    if (date == null || date.isEmpty) return '—';
    try {
      return DateTime.parse(date).year.toString();
    } catch (_) {
      return '—';
    }
  }

  double _getCarouselHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;

    if (isLandscape) return 150;
    if (screenWidth < 376) return 200;
    if (screenWidth < 430) return 220;
    if (screenWidth < 768) return 240;
    return 300;
  }

  double _getCardHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;

    if (isLandscape) return 140;
    if (screenWidth < 376) return 180;
    if (screenWidth < 430) return 190;
    if (screenWidth < 768) return 210;
    return 280;
  }

  double _getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 376) return 110;
    if (screenWidth < 430) return 120;
    if (screenWidth < 768) return 130;
    return 160;
  }

  List<String> get _filterTabs => ['All Movies', 'TV Shows', 'My List'];

  List<Map<String, dynamic>> get _myListMovies {
    if (MyList().all.isEmpty) return [];
    return _allLoadedMovies
        .where((movie) => MyList().contains(movie['id']))
        .toList();
  }

  Widget _buildMyListSection() {
    final myListMovies = _myListMovies;

    if (myListMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 80, color: Colors.white38),
            const SizedBox(height: 20),
            const Text(
              'Your My List is Empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add movies and TV shows to your list to watch later',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentFilter = 'All Movies';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _netflixRed,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Browse Movies'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My List (${myListMovies.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _showClearMyListDialog,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemCount: myListMovies.length,
            itemBuilder: (context, index) {
              return _buildGridItem(myListMovies[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final poster =
        item['poster_path'] != null ? '$imageBase${item['poster_path']}' : '';
    final isInMyList = MyList().contains(item['id']);

    return GestureDetector(
      onTap: () {
        _showInterstitialAd(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsScreen(movie: item),
            ),
          );
        });
      },
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 0.75,
              child: CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: _netflixBlack),
                errorWidget: (context, url, error) =>
                    Container(color: _netflixBlack),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  MyList().toggle(item['id']);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      MyList().contains(item['id'])
                          ? 'Added to My List'
                          : 'Removed from My List',
                    ),
                    backgroundColor: _netflixRed,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withOpacity(0.7),
                child: Icon(
                  isInMyList ? Icons.bookmark : Icons.bookmark_border,
                  size: 16,
                  color: isInMyList ? _netflixRed : Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? item['name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getYear(item),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearMyListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _netflixBlack,
        title: const Text(
          'Clear My List?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove all items from your list?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              MyList().clear();
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('My List cleared'),
                  backgroundColor: Color(0xFFE50914),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _netflixRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _netflixBlack,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _netflixRed.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterTabs.map((tab) {
                    final isSelected = _currentFilter == tab;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _currentFilter = tab),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? _netflixRed : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(tab,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: _currentFilter == 'My List'
                  ? _buildMyListSection()
                  : _buildMainContent(),
            ),
            if (_isConnected && _isBannerAdReady && _bannerAd != null)
              SizedBox(
                height: AdSize.banner.height.toDouble(),
                width: double.infinity,
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    if (isLoading && _isConnected) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    if (!_isConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 80, color: Color(0xFFE50914)),
              const SizedBox(height: 20),
              const Text(
                'No Internet Connection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please check your connection and try again.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _checkAndLoadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _netflixRed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_allLoadedMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_filter, size: 80, color: Colors.white38),
            const SizedBox(height: 20),
            const Text(
              'No Movies Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Try refreshing or check your connection',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _netflixRed,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _netflixRed,
      onRefresh: _loadInitialData,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _movieCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final trending = _movieCategories['Trending Today'] ?? [];
            if (trending.isEmpty) return const SizedBox();
            return _buildCarousel(trending);
          } else {
            final entry = _movieCategories.entries.elementAt(index - 1);
            final items = _filteredItems(entry.key);
            if (items.isEmpty) return const SizedBox();
            return _buildCategorySection(entry.key, items);
          }
        },
      ),
    );
  }

  Widget _buildCarousel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox(height: 220);
    return Builder(
      builder: (context) => CarouselSlider.builder(
        itemCount: items.length,
        itemBuilder: (context, index, _) {
          final item = items[index];
          final imageUrl = item['backdrop_path'] != null
              ? '$backdropBase${item['backdrop_path']}'
              : '';
          return GestureDetector(
            onTap: () {
              _showInterstitialAd(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailsScreen(movie: item),
                  ),
                );
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) =>
                    Container(color: _netflixBlack),
                errorWidget: (context, url, error) =>
                    Container(color: _netflixBlack),
              ),
            ),
          );
        },
        options: CarouselOptions(
          height: _getCarouselHeight(context),
          autoPlay: true,
          enlargeCenterPage: true,
          viewportFraction: 0.92,
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> items) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    _showInterstitialAd(() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FullCategoryScreen(title: title, items: items),
                        ),
                      );
                    });
                  },
                  child: const Text('View All',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                )
              ],
            ),
          ),
          SizedBox(
            height: _getCardHeight(context),
            child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _isLoadingMore[title] == true
                    ? Container(
                        width: 120,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                            color: Colors.white),
                      )
                    : GestureDetector(
                        onTap: () => _loadMore(title),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Center(
                              child: Text('Load More',
                                  style: TextStyle(color: Colors.white70))),
                        ),
                      );
              }
              return _buildItemCard(items[index]);
            },
          ),
        ),
        const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final poster =
        item['poster_path'] != null ? '$imageBase${item['poster_path']}' : '';
    final isInMyList = MyList().contains(item['id']);

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          _showInterstitialAd(() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieDetailsScreen(movie: item),
              ),
            );
          });
        },
        child: Container(
          width: _getCardWidth(context),
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 0.75,
                      child: CachedNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: _netflixBlack),
                        errorWidget: (context, url, error) =>
                            Container(color: _netflixBlack),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          MyList().toggle(item['id']);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              MyList().contains(item['id'])
                                  ? 'Added to My List'
                                  : 'Removed from My List',
                            ),
                            backgroundColor: _netflixRed,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black.withOpacity(0.7),
                        child: Icon(
                          isInMyList ? Icons.bookmark : Icons.bookmark_border,
                          size: 16,
                          color: isInMyList ? _netflixRed : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(item['title'] ?? item['name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ),
              const SizedBox(height: 2),
              Text(_getYear(item),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredItems(String category) {
    final items = _movieCategories[category] ?? [];

    if (_currentFilter == 'TV Shows') {
      return category.toLowerCase().contains('tv') ? items : [];
    }

    return items;
  }

  void _showInterstitialAd(Function rewardedAction) {
    if (!_isConnected) {
      rewardedAction();
      return;
    }

    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
      rewardedAction();
    } else {
      rewardedAction();
    }
  }
}