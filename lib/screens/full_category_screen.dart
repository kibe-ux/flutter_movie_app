// lib/screens/full_category_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'movie_details_screen.dart';
import '../utils/my_list.dart';
import '../services/ad_service.dart';
import '../widgets/safe_network_image.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w300';

class FullCategoryScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  const FullCategoryScreen(
      {super.key, required this.title, required this.items});
  @override
  State<FullCategoryScreen> createState() => _FullCategoryScreenState();
}

class _FullCategoryScreenState extends State<FullCategoryScreen> {
  late List<Map<String, dynamic>> _allItems;
  int _currentPage = 1;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _loadedIds = {};
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  @override
  void initState() {
    super.initState();
    _allItems = List.from(widget.items);
    _loadedIds.addAll(_allItems.map((item) => item['id'] ?? 0));
    _loadInterstitial();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading) {
        _loadMore();
      }
    });
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdService().interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
          _isInterstitialReady = false;
        },
      ),
    );
  }

  void _showInterstitial(VoidCallback onComplete) {
    if (_isInterstitialReady && _interstitialAd != null) {
      AdService().showInterstitial(_interstitialAd, onComplete);
      _interstitialAd = null;
      _isInterstitialReady = false;
      _loadInterstitial(); // reload for next time
    } else {
      onComplete();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    _currentPage++;
    String url;
    if (widget.title.contains('TV')) {
      // Handle TV categories
      final tvCategoryMap = {
        'TV Shows': '$baseUrl/tv/popular?api_key=$apiKey',
        'Trending TV Today': '$baseUrl/trending/tv/day?api_key=$apiKey',
        'Trending TV This Week': '$baseUrl/trending/tv/week?api_key=$apiKey',
        'Popular TV Shows': '$baseUrl/tv/popular?api_key=$apiKey',
        'Top Rated TV Shows': '$baseUrl/tv/top_rated?api_key=$apiKey',
        'Airing Today': '$baseUrl/tv/airing_today?api_key=$apiKey',
        'Drama & Mystery TV':
            '$baseUrl/discover/tv?api_key=$apiKey&with_genres=18,9648',
        'Sci-Fi & Fantasy TV':
            '$baseUrl/discover/tv?api_key=$apiKey&with_genres=10765',
      };
      url =
          tvCategoryMap[widget.title] ?? '$baseUrl/tv/popular?api_key=$apiKey';
    } else {
      final categoryMap = {
        'Trending Today': '$baseUrl/trending/movie/day?api_key=$apiKey',
        'Trending This Week': '$baseUrl/trending/movie/week?api_key=$apiKey',
        'Now Playing': '$baseUrl/movie/now_playing?api_key=$apiKey',
        'Upcoming Releases': '$baseUrl/movie/upcoming?api_key=$apiKey',
        'Recently Released':
            '$baseUrl/discover/movie?api_key=$apiKey&sort_by=release_date.desc',
        'Top Rated': '$baseUrl/movie/top_rated?api_key=$apiKey',
        'Popular Movies': '$baseUrl/movie/popular?api_key=$apiKey',
        'Most Watched Now':
            '$baseUrl/discover/movie?api_key=$apiKey&sort_by=popularity.desc',
        'Box Office Hits':
            '$baseUrl/discover/movie?api_key=$apiKey&sort_by=revenue.desc',
        'Award Winning Movies':
            '$baseUrl/discover/movie?api_key=$apiKey&vote_average.gte=7',
        'Hollywood Movies':
            '$baseUrl/discover/movie?api_key=$apiKey&with_original_language=en',
        'Romance & Fantasy':
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=10749,14',
        'Horror & Mystery':
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=27,9648',
      };
      url =
          categoryMap[widget.title] ?? '$baseUrl/movie/popular?api_key=$apiKey';
    }
    url += '&page=$_currentPage&language=en-US';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final results =
            (json.decode(response.body)['results'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>()
                .where((item) {
          final id = item['id'] ?? 0;
          return !_loadedIds.contains(id);
        }).toList();

        if (results.isNotEmpty) {
          setState(() {
            _allItems.addAll(results);
            _loadedIds.addAll(results.map((item) => item['id'] ?? 0));
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _interstitialAd?.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _allItems.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _allItems.length) {
            return Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : GestureDetector(
                      onTap: _loadMore,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'Load More',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
            );
          }
          final item = _allItems[index];
          final poster = item['poster_path'] != null
              ? '$imageBase${item['poster_path']}'
              : '';
          final isInMyList = MyList().contains(item['id'] ?? 0); // ADDED
          return GestureDetector(
            onTap: () {
              _showInterstitial(() {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 0.7,
                      child: SafeNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        item['title'] ?? item['name'] ?? 'Unknown',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            ((item['vote_average'] ?? 0) as num)
                                .toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          ),
                          const Spacer(),
                          Text(
                            _getYear(item),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        MyList().toggle(item['id'] ?? 0);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            MyList().contains(item['id'] ?? 0)
                                ? 'Added to My List'
                                : 'Removed from My List',
                          ),
                          backgroundColor: const Color(0xFFE50914),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isInMyList ? Icons.bookmark : Icons.bookmark_border,
                        color:
                            isInMyList ? const Color(0xFFE50914) : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
