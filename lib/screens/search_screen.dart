import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_details_screen.dart';
import '../utils/my_list.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '9c12c3b471405cfbfeca767fa3ea8907';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required Set<int> myListIds});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    // Input validation
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }

    // Sanitize input to prevent issues
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchQuery = sanitizedQuery;
    });

    try {
      final movieResponse = http.get(Uri.parse(
          '$baseUrl/search/movie?api_key=$apiKey&query=$sanitizedQuery&language=en-US')).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Search request timed out'),
      );
      
      final tvResponse = http.get(Uri.parse(
          '$baseUrl/search/tv?api_key=$apiKey&query=$sanitizedQuery&language=en-US')).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Search request timed out'),
      );

      final results = await Future.wait([movieResponse, tvResponse]);
      
      if (!mounted) return; // Check if widget still mounted

      final movies = results[0].statusCode == 200
          ? (json.decode(results[0].body)['results'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      
      final tvShows = results[1].statusCode == 200
          ? (json.decode(results[1].body)['results'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          _searchResults = [...movies, ...tvShows];
          _isSearching = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search timed out. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: ${e.toString()}')),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
      _searchQuery = '';
    });
  }

  Widget _buildSearchResultItem(Map<String, dynamic> item) {
    final posterPath = item['poster_path'] ?? item['backdrop_path'];
    final imageUrl = posterPath != null ? '$imageBase$posterPath' : null;
    final title = item['title'] ?? item['name'] ?? 'Unknown Title';
    final overview = item['overview'] ?? 'No description available';
    final isInMyList = MyList().contains(item['id']); // UPDATED
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: item)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 70,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: const Color(0xFF2A2A2A),
                  ),
                  child: imageUrl == null
                      ? const Icon(Icons.movie_rounded,
                          color: Colors.white38, size: 30)
                      : null,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        MyList().toggle(item['id']); // UPDATED
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              MyList().contains(item['id'])
                                  ? 'Added to My List'
                                  : 'Removed from My List',
                            ),
                            backgroundColor: const Color(0xFFE50914),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      });
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      child: Icon(
                        isInMyList ? Icons.bookmark : Icons.bookmark_border,
                        size: 16,
                        color:
                            isInMyList ? const Color(0xFFE50914) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(overview,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _getYear(item),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item['title'] != null
                              ? const Color(0xFFE50914).withValues(alpha: 0.2)
                              : const Color(0xFF00D4FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['title'] != null ? 'MOVIE' : 'TV SHOW',
                          style: TextStyle(
                            color: item['title'] != null
                                ? const Color(0xFFE50914)
                                : const Color(0xFF00D4FF),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Movies & TV Shows...',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: _clearSearch)
                : null,
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bookmark,
                    color: Color(0xFFE50914),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${MyList().all.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isSearching
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Search for movies and TV shows...'
                            : 'No results found for "$_searchQuery"',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_searchQuery.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            'Type to find your favorite content',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) =>
                      _buildSearchResultItem(_searchResults[index]),
                ),
    );
  }
}
