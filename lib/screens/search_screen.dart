import '../widgets/cinema_app_bar_surface.dart';
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
import '../utils/cinema_palette.dart';
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
  final Map<String, List<Map<String, dynamic>>> _genresByType = {};
  String _searchType = 'all';
  String? _searchError;

  List<Map<String, dynamic>> get _genres {
    final byName = <String, Map<String, dynamic>>{};
    for (final type in _searchType == 'all' ? ['movie', 'tv'] : [_searchType]) {
      for (final genre in _genresByType[type] ?? <Map<String, dynamic>>[]) {
        byName[genre['name'] as String] = genre;
      }
    }
    return byName.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  Timer? _debounce;
  int _requestToken = 0;
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _searchFocusNode.addListener(() => setState(() {}));
    _loadSearchHistory();
    _loadGenres();
  }

  @override
  void dispose() {
    ++_requestToken;
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _loadGenres() async {
    await Future.wait(['movie', 'tv'].map((type) async {
      try {
        final cacheKey = '${type}_genres';
        final cached =
            CacheService.getMemCache<List<Map<String, dynamic>>>(cacheKey);
        if (cached != null) {
          if (mounted) setState(() => _genresByType[type] = cached);
          return;
        }
        final uri = Uri.parse('${AppTheme.baseUrl}/genre/$type/list')
            .replace(queryParameters: {'api_key': apiKey, 'language': 'en-US'});
        final response = await http.get(uri).timeout(AppTheme.apiTimeout);
        if (response.statusCode != 200) return;
        final genres = List<Map<String, dynamic>>.from(
            json.decode(response.body)['genres'] ?? []);
        CacheService.setMemCache(cacheKey, genres,
            ttl: const Duration(days: 7));
        if (mounted) setState(() => _genresByType[type] = genres);
      } catch (_) {
        debugPrint('Search genres unavailable for $type');
      }
    }));
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _resetSearch();
      return;
    }
    // Debounce so we don't fire a request on every keystroke.
    ++_requestToken;
    setState(() {
      _searchQuery = query.trim();
      _isSearching = true;
      _shimmerController.repeat(reverse: true);
      _searchError = null;
    });
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
      _shimmerController.stop();
      _searchQuery = '';
      _searchError = null;
    });
  }

  Future<void> _performSearch(String query) async {
    _debounce?.cancel();
    final sanitizedQuery = query.trim();
    if (sanitizedQuery.isEmpty) {
      _resetSearch();
      return;
    }

    // Invalidate any in-flight request so stale results never win.
    final requestToken = ++_requestToken;
    final types = _searchType == 'all' ? ['movie', 'tv'] : [_searchType];
    setState(() {
      _isSearching = true;
      _shimmerController.repeat(reverse: true);
      _searchQuery = sanitizedQuery;
      _searchError = null;
      _searchResults = [];
    });
    try {
        // Only show movies / TV shows that have already been released so we
        // don't surface content that users cannot yet download or watch.

      // Add to search history
      if (_selectedGenre.isNotEmpty &&
          types.any((type) => !_genresByType.containsKey(type))) {
        await _loadGenres();
        if (!mounted || requestToken != _requestToken) return;
        if (types.any((type) => !_genresByType.containsKey(type))) {
          throw StateError('Genre metadata unavailable');
        }
      }
      final pages = await Future.wait(types.map((type) async {
        final response = await http
            .get(_buildSearchUri(type, sanitizedQuery))
            .timeout(AppTheme.apiTimeout);
        if (response.statusCode != 200) throw StateError('Search unavailable');
        final raw =
            json.decode(response.body)['results'] as List<dynamic>? ?? [];
        return raw
            .cast<Map<String, dynamic>>()
            .map((item) => {...item, 'media_type': type})
            .toList();
      }));
      if (!mounted || requestToken != _requestToken) return;
      final seen = <String>{};
      final results = filterReleasedMovies(pages.expand((page) => page))
          .where((item) => seen.add('${item['media_type']}:${item['id']}'))
          .where(_matchesFilters)
          .toList();
      final normalizedQuery = sanitizedQuery.toLowerCase();
      int rank(Map<String, dynamic> item) {
        final title =
            (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
        if (title == normalizedQuery) return 0;
        if (title.startsWith(normalizedQuery)) return 1;
        if (title.contains(normalizedQuery)) return 2;
        return 3;
      }

      results.sort((a, b) {
        final relevance = rank(a).compareTo(rank(b));
        if (relevance != 0) return relevance;
        return ((b['popularity'] as num?) ?? 0)
            .compareTo((a['popularity'] as num?) ?? 0);
      });
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _shimmerController.stop();
        _searchHistory
            .removeWhere((entry) => entry.toLowerCase() == normalizedQuery);
        _searchHistory.insert(0, sanitizedQuery);
        _searchHistory = _searchHistory.take(10).toList();
      });
      unawaited(_saveSearchHistory());
    } catch (error) {
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _isSearching = false;
        _shimmerController.stop();
        _searchError = error is TimeoutException
            ? 'Search timed out. Please try again.'
            : 'Unable to load results. Check your connection and try again.';
      });
    }
  }

  bool _matchesFilters(Map<String, dynamic> item) {
    if (_selectedYear.isNotEmpty && _getYear(item) != _selectedYear) {
      return false;
    }
    if (_selectedGenre.isEmpty) return true;
    final type = item['media_type'] as String;
    final genres = _genresByType[type] ?? [];
    final ids = genres
        .where((genre) => genre['name'] == _selectedGenre)
        .map((genre) => genre['id'])
        .toSet();
    return (item['genre_ids'] as List? ?? []).any(ids.contains);
  }

  Uri _buildSearchUri(String type, String query) {
    return Uri.parse('${AppTheme.baseUrl}/search/$type')
        .replace(queryParameters: {
      'api_key': apiKey,
      'query': query,
      'language': 'en-US',
      'include_adult': 'false',
      if (_selectedYear.isNotEmpty)
        (type == 'movie' ? 'year' : 'first_air_date_year'): _selectedYear,
    });
  }

  void _setSearchType(String type) {
    if (_searchType == type) return;
    _debounce?.cancel();
    ++_requestToken;
    setState(() {
      _searchType = type;
      if (!_genres.any((genre) => genre['name'] == _selectedGenre)) {
        _selectedGenre = '';
      }
    });
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _removeFilter({bool genre = false, bool year = false}) {
    setState(() {
      if (genre) _selectedGenre = '';
      if (year) _selectedYear = '';
    });
    if (_searchController.text.trim().isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  Widget _buildSearchControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'movie', label: Text('Movies')),
              ButtonSegment(value: 'tv', label: Text('TV Shows')),
            ],
            selected: {_searchType},
            onSelectionChanged: (values) => _setSearchType(values.single),
            style: SegmentedButton.styleFrom(
              foregroundColor: CinemaPalette.ivory,
              backgroundColor: CinemaPalette.surface,
              selectedForegroundColor: CinemaPalette.background,
              selectedBackgroundColor: CinemaPalette.gold,
            ),
          ),
        ),
        if (_selectedGenre.isNotEmpty || _selectedYear.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (_selectedGenre.isNotEmpty)
                _filterChip(_selectedGenre, () => _removeFilter(genre: true)),
              if (_selectedYear.isNotEmpty)
                _filterChip(_selectedYear, () => _removeFilter(year: true)),
              TextButton(
                onPressed: () => _removeFilter(genre: true, year: true),
                style:
                    TextButton.styleFrom(foregroundColor: CinemaPalette.gold),
                child: const Text('Clear filters'),
              ),
            ]),
          ),
        if (_searchQuery.isNotEmpty && !_isSearching && _searchError == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                '${_searchResults.length} ${_searchResults.length == 1 ? 'result' : 'results'} \u00b7 Best matches first',
                style:
                    const TextStyle(color: CinemaPalette.muted, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _filterChip(String label, VoidCallback onDeleted) => InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        labelStyle: const TextStyle(color: CinemaPalette.ivory),
        backgroundColor: CinemaPalette.surface,
        side: BorderSide(color: CinemaPalette.gold.withValues(alpha: .3)),
        deleteIconColor: CinemaPalette.gold,
      );

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
              color: CinemaPalette.surface,
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
                            color: CinemaPalette.muted,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 24),
                const Text('Refine your search',
                    style: TextStyle(
                        color: CinemaPalette.ivory,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                _buildFilterDropdown(
                  label: 'Genre',
                  value: draftGenre,
                  items: _genres
                      .map((genre) => DropdownMenuItem<String>(
                          value: genre['name'] as String,
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
                    backgroundColor: CinemaPalette.gold,
                    foregroundColor: CinemaPalette.background,
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
      dropdownColor: CinemaPalette.surface,
      iconEnabledColor: CinemaPalette.gold,
      style: const TextStyle(color: CinemaPalette.ivory),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: CinemaPalette.muted),
          filled: true,
          fillColor: CinemaPalette.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: CinemaPalette.gold))),
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
    final tagColor = isMovie ? CinemaPalette.gold : CinemaPalette.ivory;
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
                color: CinemaPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: CinemaPalette.ivory.withValues(alpha: 0.05))),
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
                              color: CinemaPalette.muted, fontSize: 12)),
                    ]),
                    const SizedBox(height: 9),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: CinemaPalette.ivory,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Expanded(
                        child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      CinemaPalette.ivory,
                                      Colors.transparent
                                    ],
                                    stops: [
                                      0.62,
                                      1
                                    ]).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: Text(overview,
                                maxLines: 3,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                    color: CinemaPalette.muted,
                                    fontSize: 12,
                                    height: 1.35)))),
                  ])),
              IconButton(
                tooltip: isInMyList ? 'Remove from My List' : 'Add to My List',
                icon: Icon(
                    isInMyList
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color:
                        isInMyList ? CinemaPalette.gold : CinemaPalette.muted),
                onPressed: () => setState(() {
                  MyList().toggle(item['id']);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(MyList().contains(item['id'])
                          ? 'Added to My List'
                          : 'Removed from My List'),
                      backgroundColor: CinemaPalette.wine,
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
    if (_searchError != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              color: CinemaPalette.gold, size: 48),
          const SizedBox(height: 16),
          Text(_searchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CinemaPalette.muted)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _performSearch(_searchController.text),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: CinemaPalette.gold),
          ),
        ]),
      ));
    }
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
                    color: CinemaPalette.surface,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Container(
                      width: 80,
                      height: 120,
                      decoration: BoxDecoration(
                          color: CinemaPalette.wine,
                          borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Container(
                            width: 64, height: 12, color: CinemaPalette.wine),
                        const SizedBox(height: 14),
                        Container(height: 18, color: CinemaPalette.wine),
                        const SizedBox(height: 10),
                        Container(height: 12, color: CinemaPalette.wine),
                        const SizedBox(height: 7),
                        FractionallySizedBox(
                            widthFactor: .7,
                            child: Container(
                                height: 12, color: CinemaPalette.wine))
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
                      colors: [CinemaPalette.gold, CinemaPalette.wine])
                  .createShader(bounds),
              child: Icon(icon,
                  size: 82, color: CinemaPalette.ivory.withValues(alpha: .42))),
          const SizedBox(height: 22),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: CinemaPalette.ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CinemaPalette.muted, fontSize: 14)),
        ]),
      ));

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return _buildEmptyState(
          Icons.local_movies_rounded,
          'Find your next favorite.',
          'Search for movies and TV shows you love.');
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Recent searches',
              style: TextStyle(
                  color: CinemaPalette.ivory,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          TextButton(
              onPressed: _clearHistory,
              child: const Text('Clear all',
                  style: TextStyle(color: CinemaPalette.gold)))
        ]),
        const SizedBox(height: 14),
        Wrap(
            spacing: 9,
            runSpacing: 10,
            children: _searchHistory
                .map((query) => InputChip(
                      avatar: const Icon(Icons.history_rounded,
                          color: CinemaPalette.muted, size: 17),
                      label: Text(query),
                      labelStyle: const TextStyle(
                          color: CinemaPalette.ivory,
                          fontWeight: FontWeight.w600),
                      backgroundColor: CinemaPalette.surface,
                      side: BorderSide.none,
                      deleteIcon: const Icon(Icons.close_rounded,
                          color: CinemaPalette.muted, size: 17),
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
      backgroundColor: CinemaPalette.background,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: CinemaPalette.wine,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 92,
            flexibleSpace: CinemaAppBarSurface(
                child: SafeArea(
                    child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                            color: CinemaPalette.surface.withValues(alpha: .82),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: _searchFocusNode.hasFocus
                                    ? CinemaPalette.gold.withValues(alpha: .7)
                                    : CinemaPalette.ivory
                                        .withValues(alpha: .12)),
                            boxShadow: _searchFocusNode.hasFocus
                                ? [
                                    BoxShadow(
                                        color: CinemaPalette.gold
                                            .withValues(alpha: .18),
                                        blurRadius: 18)
                                  ]
                                : null),
                        child: Row(children: [
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.search_rounded,
                                  color: CinemaPalette.muted)),
                          Expanded(
                              child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  cursorColor: CinemaPalette.gold,
                                  style: const TextStyle(
                                      color: CinemaPalette.appBarText),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (query) {
                                    _debounce?.cancel();
                                    _performSearch(query);
                                  },
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                      hintText: 'Search movies & TV shows',
                                      hintStyle: const TextStyle(
                                          color: CinemaPalette.muted),
                                      border: InputBorder.none,
                                      suffixIcon: _searchController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  color: CinemaPalette.muted),
                                              onPressed: _clearSearch)
                                          : null))),
                          IconButton(
                              onPressed: _showFiltersSheet,
                              tooltip: 'Filters',
                              icon: Icon(Icons.tune_rounded,
                                  color: (_selectedGenre.isNotEmpty ||
                                          _selectedYear.isNotEmpty)
                                      ? CinemaPalette.gold
                                      : CinemaPalette.ivory)),
                        ])),
                  )),
            ))),
          ),
          SliverToBoxAdapter(child: _buildSearchControls()),
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
