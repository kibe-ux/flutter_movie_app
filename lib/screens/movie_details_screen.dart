import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const String apiKey = '30e125ca82f6e71828b3a30c47ea67c2';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';
const String backdropBase = 'https://image.tmdb.org/t/p/w780';
const String profileBase = 'https://image.tmdb.org/t/p/w185';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> similarMovies = [];
  bool isLoadingCast = true;
  bool isLoadingSimilar = true;
  bool isFavorite = false;

  BannerAd? _bannerAd;

  // Rewarded Ad
  RewardedAd? _rewardedAd;
  bool _isRewardedLoaded = false;

  @override
  void initState() {
    super.initState();
    fetchCast();
    fetchSimilarMovies();
    _loadRewardedAd();
    _loadBannerAd();
  }

  // LOAD REWARDED AD
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Rewarded Test Ad
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoaded = false;
        },
      ),
    );
  }

  void _showRewardedAd(Function rewardedAction) {
    if (_isRewardedLoaded && _rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (_, reward) {
        rewardedAction();
      });

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
        },
      );

      _rewardedAd = null;
      _isRewardedLoaded = false;
    }
  }

  // BANNER AD
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  // Fetch Cast
  Future<void> fetchCast() async {
    try {
      final movieId = widget.movie['id'];
      final response = await http.get(
          Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          cast = (data['cast'] as List?)
                  ?.take(12)
                  .map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          isLoadingCast = false;
        });
      }
    } catch (_) {
      setState(() => isLoadingCast = false);
    }
  }

  // Fetch Similar Movies
  Future<void> fetchSimilarMovies() async {
    try {
      final movieId = widget.movie['id'];
      final response = await http
          .get(Uri.parse('$baseUrl/movie/$movieId/similar?api_key=$apiKey'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          similarMovies = (data['results'] as List?)
                  ?.take(12)
                  .map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          isLoadingSimilar = false;
        });
      }
    } catch (_) {
      setState(() => isLoadingSimilar = false);
    }
  }

  Widget buildImage(String? url, {double? width, double? height, BoxFit? fit}) {
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.image_not_supported, color: Colors.white38),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFF1A1A1A),
        child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D4FF))),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF1A1A1A),
        child: const Icon(Icons.broken_image, color: Colors.white38),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final backdropUrl = movie['backdrop_path'] != null
        ? '$backdropBase${movie['backdrop_path']}'
        : null;
    final posterUrl = movie['poster_path'] != null
        ? '$imageBase${movie['poster_path']}'
        : null;
    final rating = ((movie['vote_average'] ?? 0.0) as num).toDouble();
    final year = _getYearFromDate(movie['release_date']);
    final duration = movie['runtime'] != null ? '${movie['runtime']} min' : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      bottomNavigationBar:
          _bannerAd != null ? SizedBox(height: 50, child: AdWidget(ad: _bannerAd!)) : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: FlexibleSpaceBar(
              background: buildImage(backdropUrl,
                  width: double.infinity, height: 300, fit: BoxFit.cover),
            ),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(posterUrl, movie, rating, year, duration),
                  const SizedBox(height: 24),
                  _buildTrailersSection(),
                  const SizedBox(height: 24),
                  _buildOverview(movie),
                  const SizedBox(height: 24),
                  _buildCastSection(),
                  const SizedBox(height: 24),
                  _buildSimilarMoviesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
      String? posterUrl, Map<String, dynamic> movie, double rating, String year, String duration) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: buildImage(posterUrl, width: 120, height: 180, fit: BoxFit.cover),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie['title'] ?? 'Unknown Title',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text(year,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
              if (duration.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(duration,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrailersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF00D4FF).withOpacity(0.1),
            Color(0xFF0099CC).withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF00D4FF).withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trailers & Downloads',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showRewardedAd(() {
                      // Play Trailer Action
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Reward Granted: Trailer Unlocked")),
                      );
                    });
                  },
                  icon: const Icon(Icons.play_arrow_rounded,
                      color: Color(0xFF00D4FF)),
                  label: const Text('Watch Trailer',
                      style: TextStyle(
                          color: Color(0xFF00D4FF),
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _showRewardedAd(() {
                      // Download Action
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Reward Granted: Download Started")),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFF00D4FF), width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Download Now',
                      style: TextStyle(
                          color: Color(0xFF00D4FF),
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> movie) {
    if (movie['overview'] == null ||
        (movie['overview'] as String).isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(movie['overview'],
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  // CAST Section with Title
  Widget _buildCastSection() {
    if (isLoadingCast) {
      return const SizedBox(
          height: 160,
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF))));
    }
    if (cast.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Cast",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            itemBuilder: (context, index) {
              final person = cast[index];
              final profileUrl = person['profile_path'] != null
                  ? '$profileBase${person['profile_path']}'
                  : null;

              return Container(
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(child: buildImage(profileUrl)),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        person['name'] ?? 'Unknown',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        person['character'] ?? '',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // SIMILAR MOVIES Section
  Widget _buildSimilarMoviesSection() {
    if (isLoadingSimilar) {
      return const SizedBox(
          height: 200,
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF))));
    }
    if (similarMovies.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Similar Movies",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: similarMovies.length,
            itemBuilder: (context, index) {
              final movie = similarMovies[index];
              final posterUrl = movie['poster_path'] != null
                  ? '$imageBase${movie['poster_path']}'
                  : null;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MovieDetailsScreen(movie: movie)),
                ),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(15)),
                        child: buildImage(posterUrl,
                            height: 170, width: 130, fit: BoxFit.cover),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          movie['title'] ?? 'Unknown',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getYearFromDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown';
    try {
      return DateTime.parse(date).year.toString();
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }
}
