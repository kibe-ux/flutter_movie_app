import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'safe_network_image.dart';

class HomeMovieCarousel extends StatefulWidget {
  const HomeMovieCarousel(
      {super.key,
      required this.movies,
      required this.height,
      required this.onMovieTap});
  final List<Map<String, dynamic>> movies;
  final double height;
  final ValueChanged<Map<String, dynamic>> onMovieTap;

  @override
  State<HomeMovieCarousel> createState() => _HomeMovieCarouselState();
}

class _HomeMovieCarouselState extends State<HomeMovieCarousel> {
  Widget? _slider;
  String? _configuration;
  Object? _selectedId;
  bool _restored = false;
  static const _storageId = 'home-carousel-selected-movie';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _selectedId = PageStorage.maybeOf(context)
          ?.readState(context, identifier: _storageId);
      _restored = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    if (movies.isEmpty) return SizedBox(height: widget.height);
    final active = TickerMode.valuesOf(context).enabled;
    final configuration = '${widget.height}:$active:'
        '${movies.map((movie) => '${movie['id']}:${movie['backdrop_path']}:${movie['poster_path']}').join('|')}';
    if (_slider == null || configuration != _configuration) {
      final selected = movies.indexWhere((movie) => movie['id'] == _selectedId);
      final initialPage = selected >= 0 ? selected : 0;
      _selectedId = movies[initialPage]['id'];
      _configuration = configuration;
      // Keep the same slider widget across unrelated Home updates. The
      // package recreates its page controller in didUpdateWidget. A genuine
      // content/layout change starts a new slider at the selected title.
      _slider = CarouselSlider.builder(
        key: ValueKey(configuration),
        itemCount: movies.length,
        options: CarouselOptions(
          height: widget.height,
          initialPage: initialPage,
          autoPlay: active && movies.length > 1,
          enableInfiniteScroll: movies.length > 1,
          enlargeCenterPage: true,
          viewportFraction: 0.92,
          onPageChanged: (index, _) {
            if (index >= widget.movies.length) return;
            _selectedId = widget.movies[index]['id'];
            PageStorage.maybeOf(context)
                ?.writeState(context, _selectedId, identifier: _storageId);
          },
        ),
        itemBuilder: (context, index, _) {
          final movie = widget.movies[index];
          final backdrop = movie['backdrop_path'];
          final poster = movie['poster_path'];
          final image = backdrop != null
              ? 'https://image.tmdb.org/t/p/w780$backdrop'
              : poster != null
                  ? 'https://image.tmdb.org/t/p/w500$poster'
                  : null;
          return Semantics(
              label: movie['title']?.toString(),
              button: true,
              child: GestureDetector(
                onTap: () => widget.onMovieTap(widget.movies[index]),
                child: SafeNetworkImage(
                    imageUrl: image,
                    height: widget.height,
                    width: MediaQuery.sizeOf(context).width * 0.92,
                    borderRadius: BorderRadius.circular(12)),
              ));
        },
      );
    }
    return _slider!;
  }
}
