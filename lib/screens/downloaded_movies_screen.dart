import '../utils/cinema_palette.dart';
import '../widgets/cinema_app_bar_surface.dart';
import 'package:flutter/material.dart';

import '../services/movie_download_service.dart' show DownloadedMovie;
import '../services/download_service.dart';
import '../services/ad_service.dart';
import 'video_player_screen.dart';

class DownloadedMoviesScreen extends StatefulWidget {
  const DownloadedMoviesScreen({super.key});

  @override
  State<DownloadedMoviesScreen> createState() => _DownloadedMoviesScreenState();
}

class _DownloadedMoviesScreenState extends State<DownloadedMoviesScreen> {
  final DownloadService _service = DownloadService();
  bool _isLoading = true;
  String? _error;
  List<DownloadedMovie> _movies = const [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedMovies();
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
    final deleted = await _service.deleteDownloadedMovie(movie.path);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not delete this download. Please try again.')),
      );
      return;
    }
    await _loadDownloadedMovies();
  }

  void _showInterstitialAd(Function actionAfterAd) {
    AdService().onActionWithAd(actionAfterAd,
        isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: CinemaPalette.ivory,
        surfaceTintColor: Colors.transparent,
        backgroundColor: CinemaPalette.background,
        flexibleSpace: const CinemaAppBarSurface(),
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
          subtitle:
              Text('${movie.formattedSize} • ${movie.modifiedAt.toLocal()}'),
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
                        builder: (_) =>
                            VideoPlayerScreen(localFilePath: movie.path),
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
