import 'package:flutter/material.dart';
import '../utils/my_list.dart';
import 'movie_details_screen.dart';
import '../services/ad_service.dart';
import '../services/media_api_service.dart';
import '../widgets/safe_network_image.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  List<Map<String, dynamic>> _myListMovies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyListMovies();
  }

  Future<void> _loadMyListMovies() async {
    setState(() => _isLoading = true);

    try {
      final savedIds = MyList().all;
      final movieResults = await Future.wait(
        savedIds.map(MediaApiService.fetchMovieDetails),
      );
      final myListMovies =
          movieResults.whereType<Map<String, dynamic>>().toList();

      if (mounted) {
        setState(() {
          _myListMovies = myListMovies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load My List: $e')),
        );
      }
    }
  }

  Future<void> _removeFromMyList(int movieId) async {
    await MyList().toggleAndWait(movieId);
    if (mounted) {
      setState(() {
        _myListMovies.removeWhere((movie) => movie['id'] == movieId);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Removed from My List')),
        );
    }
  }

  Future<void> _clearMyList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('Clear My List', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to remove all movies from My List?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MyList().clear();
      _loadMyListMovies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('My List cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My List (${_myListMovies.length})'),
        actions: [
          if (_myListMovies.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearMyList,
              tooltip: 'Clear My List',
            ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonGrid()
          : _myListMovies.isEmpty
              ? _buildEmptyState()
              : _buildMovieGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFFFFD700)],
            ).createShader(bounds),
            child: const Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your list is empty',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Movies you save will appear here.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _myListMovies.length,
      itemBuilder: (context, index) {
        final movie = _myListMovies[index];
        final movieId = movie['id'] as int?;
        if (movieId == null) return const SizedBox.shrink();

        return Dismissible(
          key: ValueKey(movieId),
          direction: DismissDirection.endToStart,
          background: _buildRemoveBackground(),
          onDismissed: (_) => _removeFromMyList(movieId),
          child: _buildMovieCard(movie),
        );
      },
    );
  }

  Widget _buildRemoveBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFE50914),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const _MovieSkeletonCard(),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    final posterUrl = movie['poster_path'] != null
        ? 'https://image.tmdb.org/t/p/w300${movie['poster_path']}'
        : null;

    return GestureDetector(
      onTap: () {
        AdService().onMoviePosterTap(() {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailsScreen(movie: movie),
            ),
          );
        },
            isActive: () =>
                mounted &&
                context.mounted &&
                (ModalRoute.of(context)?.isCurrent ?? true));
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1A27),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeNetworkImage(
              imageUrl: posterUrl,
              borderRadius: BorderRadius.circular(12),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeFromMyList(movie['id']),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark,
                    color: Color(0xFFE50914),
                    size: 16,
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
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  movie['title'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + (_controller.value * 2), -0.3),
            end: Alignment(_controller.value * 2, 0.3),
            colors: const [
              Color(0xFF1A1A27),
              Color(0xFF2A2A3A),
              Color(0xFF1A1A27),
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
