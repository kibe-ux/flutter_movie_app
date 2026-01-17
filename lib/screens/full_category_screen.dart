// lib/screens/full_category_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'movie_details_screen.dart';

const String apiKey = '9c12c3b471405cfbfeca767fa3ea8907';
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

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  @override
  void initState() {
    super.initState();
    _allItems = List.from(widget.items);
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
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
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
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (_) {
        onComplete();
        _interstitialAd!.dispose();
        _loadInterstitial(); // reload
      });
      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialReady = false;
    } else {
      onComplete();
    }
  }

  Future<void> _loadMore() async {
    _isLoading = true;
    _currentPage++;

    String url;
    if (widget.title == 'TV Shows') {
      url = '$baseUrl/tv/popular?api_key=$apiKey&page=$_currentPage';
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
      };
      url =
          categoryMap[widget.title] ?? '$baseUrl/movie/popular?api_key=$apiKey';
      url += '&page=$_currentPage';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final results =
            (json.decode(response.body)['results'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        setState(() {
          _allItems.addAll(results);
        });
      }
    } finally {
      _isLoading = false;
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
        title: Text(widget.title),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 0.7,
                  child: CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[900]),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.grey[900]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['title'] ?? item['name'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                Text(
                  _getYear(item),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
