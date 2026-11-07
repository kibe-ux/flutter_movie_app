import 'dart:async';
import '../config/home_categories.dart';
import '../utils/cinema_palette.dart';
import '../utils/catalogue_artwork.dart';
import '../utils/home_catalogue_rows.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'movie_details_screen.dart';
import 'full_category_screen.dart';
import 'my_list_screen.dart';
import '../utils/my_list.dart';
import '../services/ad_service.dart';
import '../services/home_startup_service.dart';
import '../services/catalogue_service.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/movie_hub_banner_ad.dart';
import '../widgets/connection_notice.dart';
import '../widgets/home_movie_carousel.dart';

const String imageBase = 'https://image.tmdb.org/t/p/w300';
const String backdropBase = 'https://image.tmdb.org/t/p/w780';

class HomeScreen extends StatefulWidget {
  final Set<int> myListIds;
  const HomeScreen({super.key, required this.myListIds, this.initialData});

  final HomeStartupData? initialData;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  bool _isConnected = true;
  bool _isInitialized = false;
  bool _checkingConnection = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  String _currentFilter = 'All Movies';

  final List<Map<String, dynamic>> _allLoadedMovies = [];

  final Map<String, List<Map<String, dynamic>>> _movieCategories = {
    for (final category in homeCategories) category.name: [],
  };

  final Map<String, int> _currentPage = {};
  final Map<String, bool> _isLoadingMore = {};
  final Set<String> _requestedCategories = {};
  final Map<String, String> _categoryErrors = {};
  final Map<String, bool> _hasMore = {};
  final Map<String, String?> _nextCursors = {};
  final Set<String> _resetRetries = {};
  int _loadGeneration = 0;
  bool _isRefreshing = false;
  HomeCatalogueLayout _allLayout = HomeCatalogueLayout.build(const {});
  HomeCatalogueLayout _tvLayout =
      HomeCatalogueLayout.build(const {}, tvOnly: true);
  bool _refillScheduled = false;

  HomeCatalogueLayout get _activeLayout =>
      _currentFilter == 'TV Shows' ? _tvLayout : _allLayout;

  void _rebuildHomeLayouts() {
    _allLayout = HomeCatalogueLayout.build(_movieCategories);
    _tvLayout = HomeCatalogueLayout.build(_movieCategories, tvOnly: true);
    _allLoadedMovies
      ..clear()
      ..addAll(_movieCategories.values.expand((items) => items));
  }

  void _scheduleRowRefills() {
    if (!mounted || _isRefreshing || !_isConnected || _refillScheduled) return;
    _refillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refillScheduled = false;
      if (!mounted || _isRefreshing || !_isConnected) return;
      for (final category in _requestedCategories.toList()) {
        if (_currentFilter == 'TV Shows' &&
            homeCategoriesByName[category]?.isTv != true) {
          continue;
        }
        if ((_currentPage[category] ?? 0) < 1 ||
            (_currentPage[category] ?? 0) >= 3 ||
            _isLoadingMore[category] == true ||
            _categoryErrors.containsKey(category) ||
            _hasMore[category] != true ||
            _nextCursors[category] == null) {
          continue;
        }
        if ((_activeLayout.rows[category]?.length ?? 0) < 6) {
          unawaited(_loadMore(category));
        }
      }
    });
  }

  final Color _netflixBlack = const Color(0xFF141414);
  final Color _netflixRed = const Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    if (initialData != null) {
      _isConnected = initialData.connected;
      for (final entry in initialData.categories.entries) {
        _movieCategories[entry.key] = List.of(entry.value);
        _currentPage[entry.key] = 1;
        _hasMore[entry.key] =
            initialData.hasMore[entry.key] ?? entry.value.isNotEmpty;
        _requestedCategories.add(entry.key);
      }
      _categoryErrors.addAll(initialData.categoryErrors);
      _nextCursors.addAll(initialData.nextCursors);
      _hasMore.addAll(initialData.hasMore);
      _rebuildHomeLayouts();
      _resetRetries.addAll(initialData.categoryErrors.keys);
      isLoading = false;
      _isInitialized = true;
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
      _scheduleRowRefills();
      return;
    }
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initConnectivity();
    await _checkAndLoadData();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isConnected =
        connectivityResult.any((value) => value != ConnectivityResult.none);

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (!mounted) return;
    final bool wasConnected = _isConnected;
    _isConnected = results.any((value) => value != ConnectivityResult.none);

    if (wasConnected != _isConnected) {
      if (mounted) {
        setState(() {});
      }

      if (_isConnected && !isLoading && !_checkingConnection) {
        _loadInitialData();
      }
    }
  }

  Future<void> _retryConnection() async {
    if (_checkingConnection) return;
    _checkingConnection = true;
    try {
      final results = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() {
        _isConnected = results.any((value) => value != ConnectivityResult.none);
      });
      if (_isConnected) await _loadInitialData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not check your connection. Please try again.'),
        ));
      }
    } finally {
      _checkingConnection = false;
    }
  }

  Future<void> _checkAndLoadData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    if (_isConnected) {
      await _loadInitialData();
    } else {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadInitialData() async {
    if (_allLoadedMovies.isNotEmpty) return _refreshContent();
    if (!_isConnected) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    final generation = ++_loadGeneration;
    try {
      if (mounted) {
        setState(() {
          isLoading = _allLoadedMovies.isEmpty;
          _requestedCategories.clear();
          _categoryErrors.clear();
          _hasMore.clear();
          _nextCursors.clear();
          _resetRetries.clear();
          _isLoadingMore.clear();
        });
      }

      final essentialCategories = [
        'Trending Today',
        'Now Playing',
        'Popular Movies',
        'Top Rated',
      ];
      _requestedCategories.addAll(essentialCategories);

      await Future.wait(essentialCategories
          .map((category) => _loadMore(category, reset: true)));

      if (mounted && generation == _loadGeneration) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _loadGeneration) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _refreshContent() async {
    if (_isRefreshing || !mounted) return;
    if (!_isConnected) {
      _showRefreshError();
      return;
    }
    _isRefreshing = true;
    final generation = _loadGeneration;
    final categories = _requestedCategories.toList();
    final refreshed = <String, CataloguePage>{};
    var failed = false;
    try {
      await Future.wait(categories.map((category) async {
        try {
          refreshed[category] = await const CatalogueService()
              .fetchPage(homeCategoriesByName[category]!.uri(), refresh: true);
        } on CatalogueLoadException {
          failed = true;
        }
      }));
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        for (final category in categories) {
          final result = refreshed[category];
          if (result == null) continue;
          final entry = MapEntry(category, result);
          final existing = _movieCategories[entry.key]!;
          final usedIds = existing.map((movie) => movie['id']).toSet();
          final updates = {
            for (final item in entry.value.items) item['id']: item
          };
          // Keep poster order and extra pages so refresh does not move the rows.
          for (var index = 0; index < existing.length; index++) {
            existing[index] = updates[existing[index]['id']] ?? existing[index];
          }
          existing.addAll(
              entry.value.items.where((movie) => usedIds.add(movie['id'])));
          if ((_currentPage[entry.key] ?? 1) <= 1) {
            _currentPage[entry.key] = 1;
            _hasMore[entry.key] = entry.value.hasMore;
            _nextCursors[entry.key] = entry.value.nextCursor;
          }
          _categoryErrors.remove(entry.key);
          _resetRetries.remove(entry.key);
        }
        _rebuildHomeLayouts();
      });
      if (failed) _showRefreshError();
    } finally {
      _isRefreshing = false;
      _scheduleRowRefills();
    }
  }

  void _showRefreshError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
          'Couldn\u2019t refresh. Your loaded movies are still here.'),
      backgroundColor: CinemaPalette.surface,
      action: SnackBarAction(
        label: 'Retry',
        textColor: CinemaPalette.homeAccent,
        onPressed: () => unawaited(_refreshContent()),
      ),
    ));
  }

  void _requestVisibleCategory(String category) {
    if (_isRefreshing || !_isConnected || !_requestedCategories.add(category)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadMore(category, reset: true));
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMore(String category, {bool reset = false}) async {
    if (_isRefreshing) return;
    reset = reset || _resetRetries.contains(category);
    if (!mounted || !_isConnected || _isLoadingMore[category] == true) return;
    if (!reset && _hasMore[category] == false) return;
    final definition = homeCategoriesByName[category];
    if (definition == null) return;
    final generation = _loadGeneration;
    final page = reset ? 1 : (_currentPage[category] ?? 0) + 1;
    setState(() {
      _isLoadingMore[category] = true;
      _categoryErrors.remove(category);
    });
    try {
      final result = await const CatalogueService().fetchPage(definition.uri(
          page: page, cursor: reset ? null : _nextCursors[category]));
      if (!mounted || generation != _loadGeneration) return;
      final usedIds =
          (reset ? <Map<String, dynamic>>[] : _movieCategories[category]!)
              .map((movie) => movie['id'])
              .toSet();
      final items =
          result.items.where((movie) => usedIds.add(movie['id'])).toList();
      setState(() {
        if (reset) _movieCategories[category]?.clear();
        _movieCategories[category]?.addAll(items);
        _rebuildHomeLayouts();
        _currentPage[category] = page;
        _hasMore[category] = result.hasMore;
        _nextCursors[category] = result.nextCursor;
        _resetRetries.remove(category);
      });
    } on CatalogueLoadException catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _categoryErrors[category] = error.message;
          if (reset) _resetRetries.add(category);
        });
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoadingMore[category] = false);
      }
    }
    if (mounted && generation == _loadGeneration) {
      _scheduleRowRefills();
    }
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

  double _getCarouselHeight(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = screenWidth > screenHeight;

    if (isLandscape) return 150;
    if (screenWidth < 376) return 200;
    if (screenWidth < 430) return 220;
    if (screenWidth < 768) return 240;
    return 300;
  }

  double _getCardHeight(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    // Keep the poster, two title lines and year inside the horizontal list.
    // Rotation must not shrink the list below the height of its contents.
    return _getCardWidth(context) / 0.75 +
        8 +
        (textScaler.scale(13) * 1.3).ceilToDouble() * 2 +
        (textScaler.scale(12) * 1.3).ceilToDouble();
  }

  double _getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 376) return 110;
    if (screenWidth < 430) return 120;
    if (screenWidth < 768) return 130;
    return 160;
  }

  List<String> get _filterTabs => ['All Movies', 'TV Shows', 'My List'];

  Widget _buildMyListSection() => MyListScreen(
        embedded: true,
        initialMovies: _allLoadedMovies,
        onBrowse: () => setState(() => _currentFilter = 'All Movies'),
      );

  Widget _buildFilterBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: CinemaPalette.homeHeaderGradient,
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: CinemaPalette.homeAccent.withValues(alpha: .18)),
        ),
        child: Row(children: [
          for (final tab in _filterTabs)
            Expanded(
                child: Semantics(
              button: true,
              selected: _currentFilter == tab,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: _currentFilter == tab
                      ? CinemaPalette.homeAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _currentFilter == tab
                          ? CinemaPalette.homeAccent
                          : Colors.transparent),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onTap: () {
                      if (_currentFilter == tab) return;
                      setState(() => _currentFilter = tab);
                      if (tab == 'TV Shows') {
                        _requestVisibleCategory('Popular TV Shows');
                        _requestVisibleCategory('Trending TV Today');
                      }
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 10),
                        child: Center(
                            child: Text(
                          tab,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _currentFilter == tab
                                ? CinemaPalette.background
                                : CinemaPalette.homeMuted,
                            fontSize: 12,
                            fontWeight: _currentFilter == tab
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        )),
                      ),
                    ),
                  ),
                ),
              ),
            )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentFilter == 'My List'
          ? CinemaPalette.background
          : _netflixBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: _currentFilter == 'My List'
                  ? _buildMyListSection()
                  : _buildMainContent(),
            ),
            if (_isInitialized &&
                (_currentFilter == 'My List'
                    ? MyList().all.isNotEmpty
                    : _isConnected &&
                        !isLoading &&
                        _movieCategories.keys.any(
                            (category) => _filteredItems(category).isNotEmpty)))
              const MovieHubBannerAd(placement: 'home'),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    if (isLoading && _isConnected) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    if (!_isConnected) {
      return ConnectionNotice(
        offline: true,
        title: 'You\u2019re offline',
        message:
            'Connect to Wi-Fi or mobile data to explore movies and shows, then try again.',
        onRetry: _retryConnection,
      );
    }

    if (_allLoadedMovies.isEmpty &&
        (_categoryErrors.isNotEmpty ||
            (_requestedCategories.length == _movieCategories.length &&
                !_isLoadingMore.values.any((loading) => loading)))) {
      return ConnectionNotice(
        title: _categoryErrors.isEmpty
            ? 'No movies available yet'
            : 'Canâ€™t load movies right now',
        message: _categoryErrors.isEmpty
            ? 'Try again in a moment to refresh the catalog.'
            : 'Movie Hub couldnâ€™t reach the catalog. Check your connection or try again shortly.',
        onRetry: _retryConnection,
      );
    }

    final visibleCategories = _movieCategories.entries
        .where((entry) =>
            _currentFilter != 'TV Shows' ||
            homeCategoriesByName[entry.key]?.isTv == true)
        .toList();
    return RefreshIndicator(
      color: CinemaPalette.homeAccent,
      backgroundColor: CinemaPalette.surface,
      onRefresh: _loadInitialData,
      child: ListView.builder(
        key: PageStorageKey('home-categories-$_currentFilter'),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        itemCount: visibleCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final trending = _activeLayout.featured;
            if (trending.isEmpty) return const SizedBox();
            return _buildCarousel(trending);
          } else {
            final entry = visibleCategories[index - 1];
            _requestVisibleCategory(entry.key);
            final items = _filteredItems(entry.key);
            if (items.isEmpty &&
                _currentPage.containsKey(entry.key) &&
                (_hasMore[entry.key] == false || entry.value.isNotEmpty) &&
                !_categoryErrors.containsKey(entry.key) &&
                _isLoadingMore[entry.key] != true) {
              return const SizedBox();
            }
            return _buildCategorySection(entry.key, items);
          }
        },
      ),
    );
  }

  Widget _buildCarousel(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox(height: 220);
    return HomeMovieCarousel(
      movies: items,
      height: _getCarouselHeight(context),
      onMovieTap: (item) => _showInterstitialAd(() {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: item)));
      }),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> items) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    AdService().onViewAllTap(() {
                      if (!mounted || !context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullCategoryScreen(
                            title: title,
                            items: _movieCategories[title] ?? items,
                            initialPage: _currentPage[title] ?? 1,
                            hasMore: _hasMore[title] ?? true,
                            initialCursor: _nextCursors[title],
                          ),
                        ),
                      );
                    },
                        isActive: () =>
                            mounted &&
                            context.mounted &&
                            (ModalRoute.of(context)?.isCurrent ?? true));
                  },
                  child: const Text('View All',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                )
              ],
            ),
          ),
          SizedBox(
            height: _getCardHeight(context),
            child: ListView.builder(
              key: PageStorageKey('home-posters-$title'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length + (_hasMore[title] == false ? 0 : 1),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  final loading = _isLoadingMore[title] == true;
                  final error = _categoryErrors[title];
                  return Container(
                    width: _getCardWidth(context),
                    margin: const EdgeInsets.only(right: 10),
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: 0.75,
                      child: Material(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: loading ? null : () => _loadMore(title),
                          child: Center(
                            child: loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (error != null) ...[
                                          Text(error,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12)),
                                          const SizedBox(height: 8),
                                        ],
                                        Text(
                                            error != null
                                                ? 'Retry'
                                                : 'Load More',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return _buildItemCard(items[index]);
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final poster = catalogueArtwork(item, size: 'w300') ?? '';
    final isInMyList = MyList().contains(item['id']);

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          _showInterstitialAd(() {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieDetailsScreen(movie: item),
              ),
            );
          });
        },
        child: Container(
          width: _getCardWidth(context),
          margin: const EdgeInsets.only(right: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 0.75,
                      child: SafeNetworkImage(
                        imageUrl: poster,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          MyList().toggle(item['id']);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              MyList().contains(item['id'])
                                  ? 'Added to My List'
                                  : 'Removed from My List',
                            ),
                            backgroundColor: _netflixRed,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black.withValues(alpha: 0.7),
                        child: Icon(
                          isInMyList ? Icons.bookmark : Icons.bookmark_border,
                          size: 16,
                          color: isInMyList ? _netflixRed : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(item['title'] ?? item['name'] ?? 'Unknown',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.3),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ),
              const SizedBox(height: 2),
              Text(_getYear(item),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredItems(String category) {
    return _activeLayout.rows[category] ?? [];
  }

  void _showInterstitialAd(Function rewardedAction) {
    if (!_isConnected) {
      rewardedAction();
      return;
    }

    AdService().onMoviePosterTap(rewardedAction,
        isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true));
  }
}
