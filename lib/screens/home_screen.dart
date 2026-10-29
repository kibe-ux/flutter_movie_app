import 'dart:async';
import '../config/home_categories.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'movie_details_screen.dart';
import 'full_category_screen.dart';
import '../utils/my_list.dart';
import '../services/ad_service.dart';
import '../services/home_startup_service.dart';
import '../services/catalogue_service.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/movie_hub_banner_ad.dart';
import '../widgets/connection_notice.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';
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
  final Set<String> _resetRetries = {};
  int _loadGeneration = 0;

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
        _allLoadedMovies.addAll(entry.value);
        _currentPage[entry.key] = 1;
        _requestedCategories.add(entry.key);
      }
      _categoryErrors.addAll(initialData.categoryErrors);
      _resetRetries.addAll(initialData.categoryErrors.keys);
      isLoading = false;
      _isInitialized = true;
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
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

  void _requestVisibleCategory(String category) {
    if (!_isConnected || !_requestedCategories.add(category)) return;
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
      final result = await const CatalogueService()
          .fetchPage(definition.uri(apiKey, page: page));
      if (!mounted || generation != _loadGeneration) return;
      final usedIds = _movieCategories.entries
          .where((entry) => !reset || entry.key != category)
          .expand((entry) => entry.value)
          .map((movie) => movie['id'])
          .toSet();
      final items =
          result.items.where((movie) => usedIds.add(movie['id'])).toList();
      setState(() {
        if (reset) _movieCategories[category]?.clear();
        _movieCategories[category]?.addAll(items);
        _allLoadedMovies
          ..clear()
          ..addAll(_movieCategories.values.expand((movies) => movies));
        _currentPage[category] = page;
        _hasMore[category] = result.hasMore;
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

  List<Map<String, dynamic>> get _myListMovies {
    if (MyList().all.isEmpty) return [];
    return _allLoadedMovies
        .where((movie) => MyList().contains(movie['id']))
        .toList();
  }

  Widget _buildMyListSection() {
    final myListMovies = _myListMovies;

    if (myListMovies.isEmpty) {
      return Center(
          child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border, size: 80, color: Colors.white38),
            const SizedBox(height: 20),
            const Text(
              'Your My List is Empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add movies and TV shows to your list to watch later',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentFilter = 'All Movies';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _netflixRed,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Browse Movies'),
            ),
          ],
        ),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My List (${myListMovies.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _showClearMyListDialog,
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemCount: myListMovies.length,
            itemBuilder: (context, index) {
              return _buildGridItem(myListMovies[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final poster =
        item['poster_path'] != null ? '$imageBase${item['poster_path']}' : '';
    final isInMyList = MyList().contains(item['id']);

    return GestureDetector(
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
      child: Stack(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? item['name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getYear(item),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearMyListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _netflixBlack,
        title: const Text(
          'Clear My List?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove all items from your list?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              MyList().clear();
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('My List cleared'),
                  backgroundColor: Color(0xFFE50914),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: _netflixRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _netflixBlack,
      body: SafeArea(
        child: Column(
          children: [
            if (_isInitialized &&
                (_currentFilter == 'My List'
                    ? _myListMovies.isNotEmpty
                    : _isConnected &&
                        !isLoading &&
                        _movieCategories.keys.any(
                            (category) => _filteredItems(category).isNotEmpty)))
              const MovieHubBannerAd(placement: 'home'),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _netflixRed.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterTabs.map((tab) {
                    final isSelected = _currentFilter == tab;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _currentFilter = tab),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? _netflixRed : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(tab,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: _currentFilter == 'My List'
                  ? _buildMyListSection()
                  : _buildMainContent(),
            ),
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
        title: 'You’re offline',
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
            : 'Can’t load movies right now',
        message: _categoryErrors.isEmpty
            ? 'Try again in a moment to refresh the catalog.'
            : 'Movie Hub couldn’t reach the catalog. Check your connection or try again shortly.',
        onRetry: _retryConnection,
      );
    }

    return RefreshIndicator(
      color: _netflixRed,
      onRefresh: _loadInitialData,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _movieCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final trending = _movieCategories['Trending Today'] ?? [];
            if (trending.isEmpty) return const SizedBox();
            return _buildCarousel(trending);
          } else {
            final entry = _movieCategories.entries.elementAt(index - 1);
            _requestVisibleCategory(entry.key);
            final items = _filteredItems(entry.key);
            if (items.isEmpty &&
                _currentPage.containsKey(entry.key) &&
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
    return Builder(
      builder: (context) => CarouselSlider.builder(
        itemCount: items.length,
        itemBuilder: (context, index, _) {
          final item = items[index];
          final imageUrl = item['backdrop_path'] != null
              ? '$backdropBase${item['backdrop_path']}'
              : '';
          return GestureDetector(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(color: _netflixBlack),
                errorWidget: (context, url, error) =>
                    Container(color: _netflixBlack),
              ),
            ),
          );
        },
        options: CarouselOptions(
          height: _getCarouselHeight(context),
          autoPlay: true,
          enlargeCenterPage: true,
          viewportFraction: 0.92,
        ),
      ),
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
                            items: items,
                            initialPage: _currentPage[title] ?? 1,
                            hasMore: _hasMore[title] ?? true,
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
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length + (_hasMore[title] == false ? 0 : 1),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return _isLoadingMore[title] == true
                      ? Container(
                          width: 120,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                              color: Colors.white),
                        )
                      : GestureDetector(
                          onTap: () => _loadMore(title),
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8)),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_categoryErrors.containsKey(title)) ...[
                                      Text(_categoryErrors[title]!,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12)),
                                      const SizedBox(height: 8),
                                    ],
                                    Text(
                                        _categoryErrors.containsKey(title)
                                            ? 'Retry'
                                            : 'Load More',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                  ],
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
    final poster =
        item['poster_path'] != null ? '$imageBase${item['poster_path']}' : '';
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
    final items = _movieCategories[category] ?? [];

    if (_currentFilter == 'TV Shows') {
      return homeCategoriesByName[category]?.isTv == true ? items : [];
    }

    return items;
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
