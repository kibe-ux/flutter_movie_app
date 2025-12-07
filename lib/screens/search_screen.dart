import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'movie_details_screen.dart';

const String apiKey = '30e125ca82f6e71828b3a30c47ea67c2';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';

class SearchScreen extends StatefulWidget {
  final Set<int> myListIds; // Pass the same My List set from HomeScreen
  const SearchScreen({super.key, required this.myListIds});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // Movies
      final movieResponse = await http.get(Uri.parse(
          '$baseUrl/search/movie?api_key=$apiKey&query=$query&language=en-US'));
      // TV Shows
      final tvResponse = await http.get(Uri.parse(
          '$baseUrl/search/tv?api_key=$apiKey&query=$query&language=en-US'));

      final movies = movieResponse.statusCode == 200
          ? (json.decode(movieResponse.body)['results'] as List)
              .cast<Map<String, dynamic>>()
          : [];

      final tvShows = tvResponse.statusCode == 200
          ? (json.decode(tvResponse.body)['results'] as List)
              .cast<Map<String, dynamic>>()
          : [];

      setState(() {
        _searchResults = [...movies, ...tvShows];
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => _isSearching = false);
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
    final isInMyList = widget.myListIds.contains(item['id']);

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
                        if (isInMyList) {
                          widget.myListIds.remove(item['id']);
                        } else {
                          widget.myListIds.add(item['id']);
                        }
                      });
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(isInMyList ? Icons.check : Icons.add,
                          size: 16, color: Colors.white),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            hintText: 'Search movies & TV shows...',
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
      ),
      body: _isSearching
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'start typing to sarch ...'
                        : 'No results found',
                    style: const TextStyle(color: Colors.white54),
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
