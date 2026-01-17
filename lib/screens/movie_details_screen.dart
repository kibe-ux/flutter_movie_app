// -------------------- MovieDetailsScreen.dart --------------------
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/my_list.dart';
import '../services/download_service.dart';
import 'video_player_screen.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '9c12c3b471405cfbfeca767fa3ea8907';
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
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoaded = false;
  late DownloadService _downloadService;

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService();
    fetchCast();
    fetchSimilarMovies();
    _loadInterstitialAd();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // -------------------- Ads --------------------
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoaded = false;
        },
      ),
    );
  }

  void _showInterstitialAd(Function actionAfterAd) {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
      actionAfterAd();
    } else {
      actionAfterAd();
    }
  }

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

  // -------------------- API Fetch --------------------
  Future<void> fetchCast() async {
    try {
      final movieId = widget.movie['id'];
      final response = await http
          .get(Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'));
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

  // -------------------- Helpers --------------------
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

  String _getYearFromDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown';
    try {
      return DateTime.parse(date).year.toString();
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<String?> fetchTrailerUrl(int movieId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/movie/$movieId/videos?api_key=$apiKey'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final trailer = results.firstWhere(
              (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
              orElse: () => null);
          if (trailer != null) {
            return 'https://www.youtube.com/watch?v=${trailer['key']}';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // -------------------- Build --------------------
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
      bottomNavigationBar: _bannerAd != null
          ? SizedBox(height: 50, child: AdWidget(ad: _bannerAd!))
          : null,
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
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    MyList().contains(movie['id'])
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: MyList().contains(movie['id'])
                        ? const Color(0xFFE50914)
                        : Colors.white,
                    size: 22,
                  ),
                ),
                onPressed: () {
                  MyList().toggle(movie['id']);
                  setState(() {});
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(posterUrl, movie, rating, year, duration),
                  const SizedBox(height: 24),
                  _buildTrailersSection(movie),
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

  // -------------------- Sections --------------------
  Widget _buildHeaderSection(String? posterUrl, Map<String, dynamic> movie,
      double rating, String year, String duration) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child:
              buildImage(posterUrl, width: 120, height: 180, fit: BoxFit.cover),
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------- Trailers & Downloads --------------------
  Widget _buildTrailersSection(Map<String, dynamic> movie) {
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
        border: Border.all(
            color: Color(0xFF00D4FF).withOpacity(0.3), width: 1),
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
              // Watch Trailer Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _showInterstitialAd(() async {
                      final trailerUrl =
                          await fetchTrailerUrl(movie['id']) ??
                              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                VideoPlayerScreen(videoUrl: trailerUrl)),
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
              // Download Button with Status
              Expanded(
                child: StreamBuilder<Map<int, DownloadItem>>(
                  stream: _downloadService.downloadsStream,
                  builder: (context, snapshot) {
                    final downloads = snapshot.data ?? {};
                    final download = downloads[movie['id']];
                    final status = download?.status ?? DownloadStatus.idle;
                    final progress = download?.progress ?? 0.0;

                    return _buildDownloadButton(movie, status, progress);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build download button with different states
  Widget _buildDownloadButton(Map<String, dynamic> movie, DownloadStatus status, double progress) {
    IconData icon = Icons.download_rounded;
    String label = 'Download Now';
    VoidCallback? onPressed;
    Color buttonColor = const Color(0xFF00D4FF);

    switch (status) {
      case DownloadStatus.idle:
        icon = Icons.download_rounded;
        label = 'Download Now';
        onPressed = () => _startDownload(movie);
        break;
      case DownloadStatus.downloading:
        icon = Icons.pause_rounded;
        label = '${(progress * 100).toStringAsFixed(0)}%';
        onPressed = () => _pauseDownload(movie['id']);
        buttonColor = Colors.orange;
        break;
      case DownloadStatus.paused:
        icon = Icons.play_arrow_rounded;
        label = 'Resume';
        onPressed = () => _resumeDownload(movie['id']);
        buttonColor = Colors.orange;
        break;
      case DownloadStatus.completed:
        icon = Icons.check_rounded;
        label = 'Downloaded';
        onPressed = null; // Disable for downloaded items
        buttonColor = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = Icons.error_rounded;
        label = 'Retry';
        onPressed = () => _startDownload(movie);
        buttonColor = Colors.red;
        break;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: buttonColor),
      label: Text(label,
          style: TextStyle(
              color: buttonColor,
              fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A1A),
        side: BorderSide(color: buttonColor, width: 2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  /// Start download with API integration
  void _startDownload(Map<String, dynamic> movie) {
    _showInterstitialAd(() {
      _downloadService.downloadMovie(
        movieId: movie['id'],
        movieTitle: movie['title'] ?? 'Unknown',
        posterPath: movie['poster_path'],
        // TODO: Your friend's API will provide the download URL
        // downloadUrl: 'https://your-api.com/download?movieId=${movie['id']}',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading: ${movie['title']}'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    });
  }

  /// Pause download
  void _pauseDownload(int movieId) {
    _downloadService.pauseDownload(movieId);
  }

  /// Resume download
  void _resumeDownload(int movieId) {
    _downloadService.resumeDownload(movieId);
  }

  // -------------------- Overview --------------------
  Widget _buildOverview(Map<String, dynamic> movie) {
    if (movie['overview'] == null || (movie['overview'] as String).isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(movie['overview'],
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }

  // -------------------- Cast --------------------
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
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10),
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

  // -------------------- Similar Movies --------------------
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
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: similarMovies.length,
            itemBuilder: (context, index) {
              final movie = similarMovies[index];
              final posterUrl = movie['poster_path'] != null
                  ? '$imageBase${movie['poster_path']}'
                  : null;
              return GestureDetector(
                onTap: () {
                  _showInterstitialAd(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MovieDetailsScreen(movie: movie),
                      ),
                    );
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF00D4FF)),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}
