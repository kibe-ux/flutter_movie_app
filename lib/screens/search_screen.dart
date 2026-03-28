import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie_details_screen.dart';
import '../utils/my_list.dart';
import '../widgets/safe_network_image.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w500';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  List<String> _searchHistory = [];
  String _selectedGenre = '';
  String _selectedYear = '';
  List<Map<String, dynamic>> _genres = [];
  bool _showFilters = false;
  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _loadGenres();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _loadGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/genre/movie/list?api_key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _genres = List<Map<String, dynamic>>.from(data['genres']);
        });
      }
    } catch (e) {
      // Handle error silently
    }
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
      String movieUrl =
          '$baseUrl/search/movie?api_key=$apiKey&query=$sanitizedQuery&language=en-US';
      String tvUrl =
          '$baseUrl/search/tv?api_key=$apiKey&query=$sanitizedQuery&language=en-US';

      if (_selectedGenre.isNotEmpty) {
        movieUrl += '&with_genres=$_selectedGenre';
        tvUrl += '&with_genres=$_selectedGenre';
      }

      if (_selectedYear.isNotEmpty) {
        movieUrl += '&year=$_selectedYear';
        tvUrl += '&first_air_date_year=$_selectedYear';
      }

      final movieResponse = http.get(Uri.parse(movieUrl)).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Search request timed out'),
          );

      final tvResponse = http.get(Uri.parse(tvUrl)).timeout(
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

        // Add to search history
        if (!_searchHistory.contains(sanitizedQuery)) {
          _searchHistory.insert(0, sanitizedQuery);
          if (_searchHistory.length > 10) {
            _searchHistory = _searchHistory.sublist(0, 10);
          }
          _saveSearchHistory();
        }
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

  void _removeFromHistory(String query) {
    setState(() {
      _searchHistory.remove(query);
      _saveSearchHistory();
    });
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
      _saveSearchHistory();
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
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
                SafeNetworkImage(
                  imageUrl: imageUrl,
                  width: 70,
                  height: 100,
                  borderRadius: BorderRadius.circular(12),
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

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) =>
          _buildSearchResultItem(_searchResults[index]),
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No search history',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start searching for movies and TV shows',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with Clear All
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: _clearHistory,
                icon: const Icon(Icons.clear_all, color: Color(0xFFE50914)),
                label: const Text(
                  'Clear All',
                  style: TextStyle(color: Color(0xFFE50914)),
                ),
              ),
            ],
          ),
        ),
        // History List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.history,
                    color: Colors.grey,
                  ),
                  title: Text(
                    query,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.grey,
                    ),
                    onPressed: () => _removeFromHistory(query),
                  ),
                  onTap: () {
                    _searchController.text = query;
                    _performSearch(query);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
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
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: Colors.white,
            ),
            onPressed: _toggleFilters,
            tooltip: _showFilters ? 'Hide filters' : 'Show filters',
          ),
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
      body: Column(
        children: [
          // Filters Section
          if (_showFilters)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1A1A1A),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Genre Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _selectedGenre.isEmpty ? null : _selectedGenre,
                          hint: Text(
                            'All Genres',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Genres'),
                            ),
                            ..._genres.map((genre) => DropdownMenuItem(
                                  value: genre['id'].toString(),
                                  child: Text(genre['name']),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedGenre = value ?? '';
                            });
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Year Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              _selectedYear.isEmpty ? null : _selectedYear,
                          hint: Text(
                            'All Years',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All Years'),
                            ),
                            ...List.generate(50, (index) {
                              final year = DateTime.now().year - index;
                              return DropdownMenuItem(
                                value: year.toString(),
                                child: Text(year.toString()),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedYear = value ?? '';
                            });
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedGenre.isNotEmpty || _selectedYear.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (_selectedGenre.isNotEmpty)
                            Chip(
                              label: Text(
                                'Genre: ${_genres.firstWhere(
                                  (g) => g['id'].toString() == _selectedGenre,
                                  orElse: () => {'name': 'Unknown'},
                                )['name']}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFFE50914),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _selectedGenre = '');
                                if (_searchController.text.isNotEmpty) {
                                  _performSearch(_searchController.text);
                                }
                              },
                            ),
                          if (_selectedGenre.isNotEmpty &&
                              _selectedYear.isNotEmpty)
                            const SizedBox(width: 8),
                          if (_selectedYear.isNotEmpty)
                            Chip(
                              label: Text(
                                'Year: $_selectedYear',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFFE50914),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _selectedYear = '');
                                if (_searchController.text.isNotEmpty) {
                                  _performSearch(_searchController.text);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Content Area
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                : _searchQuery.isNotEmpty
                    ? _buildSearchResults()
                    : _buildSearchHistory(),
          ),
        ],
      ),
    );
  }
}
