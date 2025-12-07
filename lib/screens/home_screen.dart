// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'movie_details_screen.dart';
import 'full_category_screen.dart';

const String apiKey = '30e125ca82f6e71828b3a30c47ea67c2';
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

  // Ads
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  // Filters
  String _currentFilter = 'All Movies';

  // Categories
  final Map<String, List<Map<String, dynamic>>> _movieCategories = {
    // Movie categories
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
    // TV categories
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
    // Movie URLs
    'Trending Today':
        '$baseUrl/trending/movie/day?api_key=$apiKey&language=en-US',
    'Trending This Week':
        '$baseUrl/trending/movie/week?api_key=$apiKey&language=en-US',
    'Now Playing': '$baseUrl/movie/now_playing?api_key=$apiKey&language=en-US',
    'Upcoming Releases':
        '$baseUrl/movie/upcoming?api_key=$apiKey&language=en-US',
    'Recently Released':
        '$baseUrl/discover/movie?api_key=$apiKey&sort_by=release_date.desc&release_date.lte=${DateTime.now().toIso8601String().split('T').first}',
    'Top Rated': '$baseUrl/movie/top_rated?api_key=$apiKey&language=en-US',
    'Popular Movies': '$baseUrl/movie/popular?api_key=$apiKey&language=en-US',
    'Most Watched Now':
        '$baseUrl/discover/movie?api_key=$apiKey&sort_by=popularity.desc',
    'Box Office Hits':
        '$baseUrl/discover/movie?api_key=$apiKey&sort_by=revenue.desc',
    'Award Winning Movies':
        '$baseUrl/discover/movie?api_key=$apiKey&vote_average.gte=7&sort_by=vote_count.desc',
    'Hollywood Movies':
        '$baseUrl/discover/movie?api_key=$apiKey&with_original_language=en&sort_by=popularity.desc',
    'Romance & Fantasy':
        '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10749,14&sort_by=popularity.desc',
    'Horror & Mystery':
        '$baseUrl/discover/movie?api_key=$apiKey&with_genres=27,9648&sort_by=popularity.desc',

    // TV URLs
    'TV Shows': '$baseUrl/tv/popular?api_key=$apiKey&language=en-US',
    'Trending TV Today':
        '$baseUrl/trending/tv/day?api_key=$apiKey&language=en-US',
    'Trending TV This Week':
        '$baseUrl/trending/tv/week?api_key=$apiKey&language=en-US',
    'Popular TV Shows': '$baseUrl/tv/popular?api_key=$apiKey&language=en-US',
    'Top Rated TV Shows':
        '$baseUrl/tv/top_rated?api_key=$apiKey&language=en-US',
    'Airing Today': '$baseUrl/tv/airing_today?api_key=$apiKey&language=en-US',
    'Drama & Mystery TV':
        '$baseUrl/discover/tv?api_key=$apiKey&with_genres=18,9648&sort_by=popularity.desc',
    'Sci-Fi & Fantasy TV':
        '$baseUrl/discover/tv?api_key=$apiKey&with_genres=10765&sort_by=popularity.desc',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAds();
      _fetchAllCategoriesBatched();
    });
  }

  void _initializeAds() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
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
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialReady = false;
        },
      ),
    );
  }

  void _showInterstitial(VoidCallback onAdComplete) {
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (_) {
        onAdComplete();
        _interstitialAd!.dispose();
        _loadInterstitial(); // reload
      }, onAdFailedToShowFullScreenContent: (_, __) {
        onAdComplete();
        _loadInterstitial();
      });
      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialReady = false;
    } else {
      onAdComplete();
    }
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _fetchAllCategoriesBatched() async {
    final categories = _movieCategories.keys.toList();
    const batchSize = 5;
    try {
      for (int i = 0; i < categories.length; i += batchSize) {
        final batch = categories.sublist(
            i,
            (i + batchSize) > categories.length
                ? categories.length
                : i + batchSize);
        await Future.wait(batch.map((c) => _loadMore(c, reset: true)));
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadMore(String category, {bool reset = false}) async {
    if (_isLoadingMore[category] == true) return;
    _isLoadingMore[category] = true;

    int page = reset ? 1 : (_currentPage[category] ?? 1) + 1;
    final cacheKey = '$category-$page';
    if (!reset && _cache.containsKey(cacheKey)) {
      _movieCategories[category]?.addAll(_cache[cacheKey]!);
      _isLoadingMore[category] = false;
      setState(() {});
      return;
    }

    final urlBase = _categoryUrls[category];
    if (urlBase == null) {
      _isLoadingMore[category] = false;
      setState(() {});
      return;
    }

    final url = '$urlBase&page=$page';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final results =
            (json.decode(response.body)['results'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()
                .where((m) => !_usedMovieIds.contains(m['id']))
                .toList();

        setState(() {
          if (reset) _movieCategories[category]?.clear();
          _movieCategories[category]?.addAll(results);
          _cache[cacheKey] = results;
          for (var m in results) _usedMovieIds.add(m['id']);
          _currentPage[category] = page;
        });
      }
    } finally {
      _isLoadingMore[category] = false;
    }
  }

  void _navigateToDetails(Map<String, dynamic> item) {
    _showInterstitial(() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: item)),
      );
    });
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

  List<String> get _filterTabs => ['All Movies', 'TV Shows', 'My List'];

  List<Map<String, dynamic>> _filteredItems(String category) {
    final items = _movieCategories[category] ?? [];
    if (_currentFilter == 'My List') {
      return items.where((m) => widget.myListIds.contains(m['id'])).toList();
    }
    if (_currentFilter == 'TV Shows') {
      // Only TV categories
      return category.toLowerCase().contains('tv') ? items : [];
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _netflixBlack,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : SafeArea(
              child: Column(
                children: [
                  // Filter Tabs
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.black,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _filterTabs.map((tab) {
                        final isSelected = _currentFilter == tab;
                        return GestureDetector(
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
                                    fontWeight: FontWeight.bold)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Movies / TV Shows List
                  Expanded(
                    child: RefreshIndicator(
                      color: _netflixRed,
                      onRefresh: () async {
                        _usedMovieIds.clear();
                        _cache.clear();
                        setState(() => isLoading = true);
                        await _fetchAllCategoriesBatched();
                        setState(() => isLoading = false);
                      },
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _movieCategories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final trending =
                                _movieCategories['Trending Today'] ?? [];
                            return _buildCarousel(trending);
                          } else {
                            final entry =
                                _movieCategories.entries.elementAt(index - 1);
                            final items = _filteredItems(entry.key);
                            if (items.isEmpty) return const SizedBox();
                            return _buildCategorySection(entry.key, items);
                          }
                        },
                      ),
                    ),
                  ),

                  // Banner Ad
                  if (_isBannerAdReady)
                    SizedBox(
                      height: _bannerAd.size.height.toDouble(),
                      width: _bannerAd.size.width.toDouble(),
                      child: AdWidget(ad: _bannerAd),
                    ),
                ],
              ),
            ),
    );
  }

  // Carousel
  Widget _buildCarousel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox(height: 250);
    return CarouselSlider.builder(
      itemCount: items.length,
      itemBuilder: (context, index, _) {
        final item = items[index];
        final imageUrl = item['backdrop_path'] != null
            ? '$backdropBase${item['backdrop_path']}'
            : '';
        return GestureDetector(
          onTap: () => _navigateToDetails(item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(color: _netflixBlack),
              errorWidget: (context, url, error) =>
                  Container(color: _netflixBlack),
            ),
          ),
        );
      },
      options: CarouselOptions(
        height: 240,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.92,
      ),
    );
  }

  // Category Section with "Load More"
  Widget _buildCategorySection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  _showRewardedAd(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FullCategoryScreen(title: title, items: items),
                      ),
                    );
                  });
                },
                child: const Text(
                  'View All',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            ],
          ),
        ),
        SizedBox(
          height: 210,
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                              child: Text(
                            'Load More',
                            style: TextStyle(color: Colors.white70),
                          )),
                        ),
                      );
              }
              return _buildItemCard(items[index]);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // Movie/TV Card
  Widget _buildItemCard(Map<String, dynamic> item) {
    final poster =
        item['poster_path'] != null ? '$imageBase${item['poster_path']}' : '';
    final isInMyList = widget.myListIds.contains(item['id']);

    return GestureDetector(
      onTap: () => _navigateToDetails(item),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
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
                        if (isInMyList) {
                          widget.myListIds.remove(item['id']);
                        } else {
                          widget.myListIds.add(item['id']);
                        }
                      });
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(isInMyList ? Icons.check : Icons.add,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                item['title'] ?? item['name'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getYear(item),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Rewarded Ad
  void _showRewardedAd(VoidCallback onComplete) {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback =
              FullScreenContentCallback(onAdDismissedFullScreenContent: (_) {
            onComplete();
            ad.dispose();
          });
          ad.show(onUserEarnedReward: (_, __) {});
        },
        onAdFailedToLoad: (_) {
          onComplete();
        },
      ),
    );
  }
}
