import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'movie_details_screen.dart';

const String apiKey = '9c12c3b471405cfbfeca767fa3ea8907';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';

// Safe Network Image
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[850],
        child: const Center(
          child: Icon(Icons.movie_rounded, color: Colors.white54, size: 40),
        ),
      );
    }

    return Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey[850],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: const Color(0xFF00D4FF),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[850],
          child: const Center(
            child: Icon(Icons.error, color: Colors.white54, size: 40),
          ),
        );
      },
    );
  }
}

// Explore Screen
class ExploreScreen extends StatefulWidget {
  final Set<int> myListIds; // shared from MainScreen

  const ExploreScreen({super.key, required this.myListIds});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> genres = [];
  List<dynamic> movies = [];
  int? selectedGenreId;
  bool isLoading = true;
  String searchQuery = '';

  late BannerAd bannerAd;
  bool isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _initAds();
    fetchGenres();
  }

  void _initAds() {
    MobileAds.instance.initialize();
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Ad
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => isAdLoaded = true),
        onAdFailedToLoad: (_, __) => setState(() => isAdLoaded = false),
      ),
    )..load();
  }

  Future<void> fetchGenres() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/genre/movie/list?api_key=$apiKey'));
      final data = json.decode(response.body);

      setState(() {
        genres = data['genres'] ?? [];
        isLoading = false;
      });

      if (genres.isNotEmpty) {
        fetchMoviesByGenre(genres.first['id']);
      }
    } catch (e) {
      print('Error fetching genres: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchMoviesByGenre(int genreId) async {
    setState(() {
      selectedGenreId = genreId;
      movies = [];
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/discover/movie?api_key=$apiKey&with_genres=$genreId'),
      );
      final data = json.decode(response.body);

      setState(() {
        movies = data['results'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching movies: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> searchMovies(String query) async {
    if (query.isEmpty) return;

    setState(() {
      movies = [];
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/movie?api_key=$apiKey&query=$query'),
      );
      final data = json.decode(response.body);

      setState(() {
        movies = data['results'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      print('Error searching movies: $e');
      setState(() => isLoading = false);
    }
  }

  Widget _buildGenresSection() {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = genre['id'] == selectedGenreId;

          return GestureDetector(
            onTap: () => fetchMoviesByGenre(genre['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF00D4FF) : Colors.grey.shade900,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  genre['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoviesGrid() {
    if (movies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'No movies found.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        final imageUrl = movie['poster_path'] != null
            ? '$imageBase${movie['poster_path']}'
            : null;
        final movieId = movie['id'] ?? 0;
        final isInMyList = widget.myListIds.contains(movieId);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MovieDetailsScreen(movie: movie)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(imageUrl: imageUrl),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 28,
                    left: 8,
                    right: 8,
                    child: Text(
                      movie['title'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isInMyList) {
                            widget.myListIds.remove(movieId);
                          } else {
                            widget.myListIds.add(movieId);
                          }
                        });
                      },
                      child: Icon(
                        isInMyList
                            ? Icons.check_circle
                            : Icons.add_circle_outline,
                        color: Colors.blueAccent,
                        size: 28,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${movie['vote_average']?.toStringAsFixed(1) ?? 'N/A'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search movies...',
          hintStyle: TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.grey.shade900,
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (value) {
          searchQuery = value.trim();
          if (searchQuery.isNotEmpty) searchMovies(searchQuery);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'Explore Movies',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Genres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildGenresSection(),
                  const SizedBox(height: 12),
                  _buildMoviesGrid(),
                  if (isAdLoaded)
                    Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: bannerAd.size.width.toDouble(),
                      height: bannerAd.size.height.toDouble(),
                      child: AdWidget(ad: bannerAd),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    bannerAd.dispose();
    super.dispose();
  }
}
