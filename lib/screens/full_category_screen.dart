// lib/screens/full_category_screen.dart
import '../utils/cinema_palette.dart';
import '../widgets/cinema_app_bar_surface.dart';
import 'package:flutter/material.dart';
import '../config/home_categories.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'movie_details_screen.dart';
import '../utils/my_list.dart';
import '../services/ad_service.dart';
import '../widgets/safe_network_image.dart';
import '../services/catalogue_service.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';
const String imageBase = 'https://image.tmdb.org/t/p/w300';

class FullCategoryScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final int initialPage;
  final bool hasMore;
  const FullCategoryScreen(
      {super.key,
      required this.title,
      required this.items,
      this.initialPage = 1,
      this.hasMore = true});
  @override
  State<FullCategoryScreen> createState() => _FullCategoryScreenState();
}

class _FullCategoryScreenState extends State<FullCategoryScreen> {
  late List<Map<String, dynamic>> _allItems;
  int _currentPage = 1;
  bool _isLoading = false;
  late bool _hasMore;
  String? _loadError;
  final ScrollController _scrollController = ScrollController();
  final Set<int> _loadedIds = {};
  @override
  void initState() {
    super.initState();
    _allItems = List.from(widget.items);
    _currentPage = widget.items.isEmpty ? 0 : widget.initialPage;
    _hasMore = widget.hasMore;
    _loadedIds.addAll(_allItems.map((item) => item['id'] ?? 0));
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore &&
          _loadError == null) {
        _loadMore();
      }
    });
    if (_allItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
  }

  void _showInterstitial(VoidCallback onComplete) {
    AdService().onMoviePosterTap(onComplete,
        isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true));
  }

  Future<void> _loadMore() async {
    if (!mounted || _isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final nextPage = _currentPage + 1;
    final category = homeCategoriesByName[widget.title];
    final uri =
        (category ?? const HomeCategory('Popular Movies', 'movie/popular'))
            .uri(apiKey, page: nextPage);
    try {
      final result = await const CatalogueService().fetchPage(uri);
      if (!mounted) return;
      setState(() {
        _allItems.addAll(
            result.items.where((item) => _loadedIds.add(item['id'] as int)));
        _currentPage = nextPage;
        _hasMore = result.hasMore;
      });
    } on CatalogueLoadException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: CinemaPalette.ivory,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const CinemaAppBarSurface(),
        backgroundColor: CinemaPalette.background,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CinemaPalette.appBarText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          const padding = 12.0;
          const spacing = 8.0;
          final columns = ((constraints.maxWidth - padding * 2 + spacing) / 128)
              .floor()
              .clamp(1, 12);
          final cardWidth =
              (constraints.maxWidth - padding * 2 - spacing * (columns - 1)) /
                  columns;
          final textScaler = MediaQuery.textScalerOf(context);
          final cardHeight = cardWidth / 0.7 +
              4 +
              (textScaler.scale(12) * 1.3).ceilToDouble() * 2 +
              (textScaler.scale(10) * 1.3).ceilToDouble();
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cardHeight,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _allItems.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _allItems.length) {
                return Container(
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_loadError != null)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(_loadError!,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ),
                            TextButton(
                              onPressed: _loadMore,
                              child: Text(
                                  _loadError == null ? 'Load More' : 'Retry',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ),
                );
              }
              final item = _allItems[index];
              final poster = item['poster_path'] != null
                  ? '$imageBase${item['poster_path']}'
                  : '';
              final isInMyList = MyList().contains(item['id'] ?? 0); // ADDED
              return GestureDetector(
                onTap: () {
                  _showInterstitial(() {
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 0.7,
                          child: SafeNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            item['title'] ?? item['name'] ?? 'Unknown',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                ((item['vote_average'] ?? 0) as num)
                                    .toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    height: 1.3),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  _getYear(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            MyList().toggle(item['id'] ?? 0);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                MyList().contains(item['id'] ?? 0)
                                    ? 'Added to My List'
                                    : 'Removed from My List',
                              ),
                              backgroundColor: const Color(0xFFE50914),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isInMyList ? Icons.bookmark : Icons.bookmark_border,
                            color: isInMyList
                                ? const Color(0xFFE50914)
                                : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
