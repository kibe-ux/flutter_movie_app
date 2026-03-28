import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/movie_download_service.dart';
import '../services/ad_service.dart';
import 'video_player_screen.dart';

class DownloadedMoviesScreen extends StatefulWidget {
  const DownloadedMoviesScreen({super.key});

  @override
  State<DownloadedMoviesScreen> createState() => _DownloadedMoviesScreenState();
}

class _DownloadedMoviesScreenState extends State<DownloadedMoviesScreen> {
  final MovieDownloadService _service = MovieDownloadService();
  bool _isLoading = true;
  String? _error;
  List<DownloadedMovie> _movies = const [];
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDownloadedMovies();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadedMovies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final movies = await _service.getDownloadedMovies();
      if (!mounted) return;
      setState(() {
        _movies = movies;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMovie(DownloadedMovie movie) async {
    await _service.deleteDownloadedMovie(movie.path);
    await _loadDownloadedMovies();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdService().interstitialAdUnitId,
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
      AdService().showInterstitial(_interstitialAd, actionAfterAd);
    } else {
      actionAfterAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Movies'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDownloadedMovies,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Center(child: Icon(Icons.error_outline, size: 64)),
          const SizedBox(height: 8),
          Center(child: Text(_error!)),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _loadDownloadedMovies,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_movies.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 140),
          Center(
            child: Column(
              children: [
                Icon(Icons.download_outlined, size: 64),
                SizedBox(height: 8),
                Text('No downloaded movies yet'),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: _movies.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final movie = _movies[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.movie_creation_outlined),
          ),
          title: Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${movie.formattedSize} • ${movie.modifiedAt.toLocal()}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Play',
                onPressed: () {
                  _showInterstitialAd(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(localFilePath: movie.path),
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.play_circle_fill_rounded),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => _deleteMovie(movie),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }
}
