import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'movie_details_screen.dart';
import '../utils/my_list.dart';
import '../utils/app_theme.dart';
import '../utils/movie_download_availability.dart';
import '../services/ad_service.dart';
import '../services/cache_service.dart';
import '../widgets/safe_network_image.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final AnimationController _shimmerController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  List<String> _searchHistory = [];
  String _selectedGenre = '';
  String _selectedYear = '';
  List<Map<String, dynamic>> _genres = [];
  Timer? _debounce;
  int _requestToken = 0;
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _searchFocusNode.addListener(() => setState(() {}));
    _loadSearchHistory();
    _loadGenres();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _shimmerController.dispose();
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
      final cached =
          CacheService.getMemCache<List<Map<String, dynamic>>>('movie_genres');
      if (cached != null) {
        if (mounted) setState(() => _genres = cached);
        return;
      }

      final uri = Uri.parse('${AppTheme.baseUrl}/genre/movie/list')
          .replace(queryParameters: {'api_key': apiKey});
      final response = await http.get(uri).timeout(AppTheme.apiTimeout);

      if (response.statusCode == 200) {
        final genres = List<Map<String, dynamic>>.from(
          json.decode(response.body)['genres'] ?? [],
        );
        CacheService.setMemCache('movie_genres', genres,
            ttl: const Duration(days: 7));
        if (mounted) setState(() => _genres = genres);
      }
    } catch (e) {
      debugPrint('Failed to load genres: $e');
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _resetSearch();
      return;
    }
    // Debounce so we don't fire a request on every keystroke.
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _performSearch(query),
    );
  }

  void _resetSearch() {
    _debounce?.cancel();
    _requestToken++;
    setState(() {
      _searchResults = [];
      _isSearching = false;
      _searchQuery = '';
    });
  }

  Future<void> _performSearch(String query) async {
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.isEmpty) {
      _resetSearch();
      return;
    }

    // Invalidate any in-flight request so stale results never win.
    final requestToken = ++_requestToken;

    setState(() {
      _isSearching = true;
      _searchQuery = sanitizedQuery;
    });

    try {
      final results = await Future.wait([
        _fetchResults(_buildSearchUri('movie', sanitizedQuery)),
        _fetchResults(_buildSearchUri('tv', sanitizedQuery)),
      ]);

      if (requestToken != _requestToken || !mounted) return;

      setState(() {
        // Only show movies / TV shows that have already been released so we
        // don't surface content that users cannot yet download or watch.
        _searchResults = filterReleasedMovies([...results[0], ...results[1]]);
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
    } on TimeoutException {
      if (requestToken != _requestToken || !mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search timed out. Please try again.')),
      );
    } catch (e) {
      debugPrint('Search error: $e');
      if (requestToken != _requestToken || !mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchResults(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(
            AppTheme.apiTimeout,
            onTimeout: () => throw TimeoutException('Search request timed out'),
          );
      return _extractResults(response);
    } on TimeoutException {
      rethrow;
    } catch (e) {
      debugPrint('Search request failed: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _extractResults(http.Response response) {
    if (response.statusCode != 200) return [];
    final results = json.decode(response.body)['results'] as List<dynamic>?;
    return results?.cast<Map<String, dynamic>>() ?? [];
  }

  Uri _buildSearchUri(String type, String query) {
    final params = <String, String>{
      'api_key': apiKey,
      'query': query,
      'language': 'en-US',
      if (_selectedGenre.isNotEmpty) 'with_genres': _selectedGenre,
    };
    if (_selectedYear.isNotEmpty) {
      params[type == 'movie' ? 'year' : 'first_air_date_year'] = _selectedYear;
    }
    return Uri.parse('${AppTheme.baseUrl}/search/$type')
        .replace(queryParameters: params);
  }

  void _clearSearch() {
    _searchController.clear();
    _resetSearch();
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

  Future<void> _showFiltersSheet() async {
    var draftGenre = _selectedGenre;
    var draftYear = _selectedYear;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.48,
        minChildSize: 0.35,
        maxChildSize: 0.78,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF12121C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 24),
                const Text('Refine your search',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                _buildFilterDropdown(
                  label: 'Genre',
                  value: draftGenre,
                  items: _genres
                      .map((genre) => DropdownMenuItem<String>(
                          value: genre['id'].toString(),
                          child: Text(genre['name'] as String)))
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => draftGenre = value ?? ''),
                ),
                const SizedBox(height: 16),
                _buildFilterDropdown(
                  label: 'Year',
                  value: draftYear,
                  items: List.generate(30, (index) {
                    final year = (DateTime.now().year - index).toString();
                    return DropdownMenuItem<String>(
                        value: year, child: Text(year));
                  }),
                  onChanged: (value) =>
                      setSheetState(() => draftYear = value ?? ''),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedGenre = draftGenre;
                      _selectedYear = draftYear;
                    });
                    Navigator.pop(context);
                    if (_searchController.text.trim().isNotEmpty) {
                      _debounce?.cancel();
                      _performSearch(_searchController.text);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: const Color(0xFF071116),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Apply Filters',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
      {required String label,
      required String value,
      required List<DropdownMenuItem<String>> items,
      required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      dropdownColor: const Color(0xFF1A1A27),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1A1A27),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
      items: [
        DropdownMenuItem<String>(value: '', child: Text('Any $label')),
        ...items
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> item) {
    final posterPath = item['poster_path'] ?? item['backdrop_path'];
    final imageUrl = posterPath != null ? '$imageBase$posterPath' : null;
    final title = item['title'] ?? item['name'] ?? 'Unknown Title';
    final overview = item['overview'] ?? 'No description available';
    final isInMyList = MyList().contains(item['id']); // UPDATED
    final isMovie = item['title'] != null;
    final tagColor = isMovie ? AppTheme.netflixRed : AppTheme.primaryBlue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => AdService().onMoviePosterTap(
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MovieDetailsScreen(movie: item))),
              isActive: () =>
                  mounted &&
                  context.mounted &&
                  (ModalRoute.of(context)?.isCurrent ?? true)),
          child: Ink(
            height: 144,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF171721),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.05))),
            child: Row(children: [
              SafeNetworkImage(
                  imageUrl: imageUrl,
                  width: 80,
                  height: 120,
                  borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: tagColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(isMovie ? 'MOVIE' : 'TV SHOW',
                              style: TextStyle(
                                  color: tagColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5))),
                      const SizedBox(width: 8),
                      Text(_getYear(item),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ]),
                    const SizedBox(height: 9),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Expanded(
                        child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.white, Colors.transparent],
                                stops: [0.62, 1]).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: Text(overview,
                                maxLines: 3,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    height: 1.35)))),
                  ])),
              IconButton(
                tooltip: isInMyList ? 'Remove from My List' : 'Add to My List',
                icon: Icon(
                    isInMyList
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isInMyList ? AppTheme.netflixRed : Colors.white70),
                onPressed: () => setState(() {
                  MyList().toggle(item['id']);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(MyList().contains(item['id'])
                          ? 'Added to My List'
                          : 'Removed from My List'),
                      backgroundColor: AppTheme.netflixRed,
                      duration: const Duration(seconds: 1)));
                }),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['release_date'] ?? item['first_air_date'];
    if (date == null || date.isEmpty) return '\u2014';
    try {
      return DateTime.parse(date).year.toString();
    } catch (_) {
      return '\u2014';
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) return _buildSkeletonResults();
    if (_searchResults.isEmpty) {
      return _buildEmptyState(
          Icons.search_off_rounded,
          "No results for '$_searchQuery'",
          'Try adjusting your search or filters');
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) =>
          _buildSearchResultItem(_searchResults[index]),
    );
  }

  Widget _buildSkeletonResults() => AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) => Opacity(
          opacity: .36 + (_shimmerController.value * .42),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: 5,
            itemBuilder: (_, __) => Container(
                height: 144,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A27),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Container(width: 64, height: 12, color: Colors.white12),
                        const SizedBox(height: 14),
                        Container(height: 18, color: Colors.white12),
                        const SizedBox(height: 10),
                        Container(height: 12, color: Colors.white10),
                        const SizedBox(height: 7),
                        FractionallySizedBox(
                            widthFactor: .7,
                            child: Container(height: 12, color: Colors.white10))
                      ]))
                ])),
          ),
        ),
      );

  Widget _buildEmptyState(IconData icon, String title, String subtitle) =>
      Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6BE3FF), Color(0xFF8E6BFF)])
                  .createShader(bounds),
              child: Icon(icon,
                  size: 82, color: Colors.white.withValues(alpha: .42))),
          const SizedBox(height: 22),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ]),
      ));

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return _buildEmptyState(
          Icons.local_movies_rounded,
          'Find your next favorite movie.',
          'Search for movies and TV shows you love.');
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent searches',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          TextButton(
              onPressed: _clearHistory,
              child: const Text('Clear all',
                  style: TextStyle(color: AppTheme.netflixRed)))
        ]),
        const SizedBox(height: 14),
        Wrap(
            spacing: 9,
            runSpacing: 10,
            children: _searchHistory
                .map((query) => InputChip(
                      avatar: const Icon(Icons.history_rounded,
                          color: Colors.white60, size: 17),
                      label: Text(query),
                      labelStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                      backgroundColor: const Color(0xFF1A1A27),
                      side: BorderSide.none,
                      deleteIcon: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 17),
                      onDeleted: () => _removeFromHistory(query),
                      onSelected: (_) {
                        FocusScope.of(context).unfocus();
                        _searchController.text = query;
                        _performSearch(query);
                      },
                    ))
                .toList()),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.netflixBlack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            toolbarHeight: 92,
            flexibleSpace: SafeArea(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF161622).withValues(alpha: .82),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: _searchFocusNode.hasFocus
                                    ? AppTheme.primaryBlue.withValues(alpha: .7)
                                    : Colors.white.withValues(alpha: .12)),
                            boxShadow: _searchFocusNode.hasFocus
                                ? [
                                    BoxShadow(
                                        color: AppTheme.primaryBlue
                                            .withValues(alpha: .18),
                                        blurRadius: 18)
                                  ]
                                : null),
                        child: Row(children: [
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.search_rounded,
                                  color: Colors.white70)),
                          Expanded(
                              child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: const TextStyle(color: Colors.white),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (query) {
                                    _debounce?.cancel();
                                    _performSearch(query);
                                  },
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                      hintText: 'Search movies & TV shows',
                                      hintStyle: const TextStyle(
                                          color: Colors.white54),
                                      border: InputBorder.none,
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.white54),
                                              onPressed: _clearSearch)
                                          : null))),
                          IconButton(
                              onPressed: _showFiltersSheet,
                              tooltip: 'Filters',
                              icon: Icon(Icons.tune_rounded,
                                  color: (_selectedGenre.isNotEmpty ||
                                          _selectedYear.isNotEmpty)
                                      ? AppTheme.primaryBlue
                                      : Colors.white)),
                        ])),
                  )),
            )),
          ),
          SliverFillRemaining(
              hasScrollBody: true,
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults()
                  : _buildSearchHistory()),
        ],
      ),
    );
  }
}
