import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/media_api_service.dart';
import 'movie_details_screen.dart';
import '../widgets/safe_network_image.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Set<int> _favorites = {};
  List<Map<String, dynamic>> _favoriteMovies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      _favorites = await FavoritesService.getFavorites();
      final movies = <Map<String, dynamic>>[];

      for (final movieId in _favorites) {
        try {
          final movieDetails = await MediaApiService.fetchMovieDetails(movieId);
          if (movieDetails != null) {
            movies.add(movieDetails);
          }
        } catch (e) {
          // Skip movies that can't be loaded
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _favoriteMovies = movies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeFromFavorites(int movieId) async {
    await FavoritesService.removeFromFavorites(movieId);
    setState(() {
      _favorites.remove(movieId);
      _favoriteMovies.removeWhere((movie) => movie['id'] == movieId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: const Color(0xFF0A0A0A),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteMovies.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No favorite movies yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add movies to your favorites from the movie details',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteMovies.length,
      itemBuilder: (context, index) {
        final movie = _favoriteMovies[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF1A1A1A),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SafeNetworkImage(
                imageUrl:
                    'https://image.tmdb.org/t/p/w92${movie['poster_path']}',
                width: 50,
                height: 75,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(
              movie['title'] ?? 'Unknown Title',
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              movie['release_date']?.substring(0, 4) ?? 'Unknown Year',
              style: TextStyle(color: Colors.grey[400]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () => _removeFromFavorites(movie['id']),
              tooltip: 'Remove from favorites',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieDetailsScreen(movie: movie),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
