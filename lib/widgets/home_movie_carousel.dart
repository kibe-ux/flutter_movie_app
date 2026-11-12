import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'safe_network_image.dart';
import '../utils/catalogue_artwork.dart';
import '../utils/cinema_palette.dart';

class HomeMovieCarousel extends StatefulWidget {
  const HomeMovieCarousel(
      {super.key,
      this.mediaType = 'movie',
      required this.movies,
      required this.height,
      this.isSaved,
      this.onBookmarkTap,
      this.bookmarkChanges,
      required this.onMovieTap});
  final List<Map<String, dynamic>> movies;
  final String mediaType;
  final double height;
  final ValueChanged<Map<String, dynamic>> onMovieTap;
  final bool Function(Map<String, dynamic>)? isSaved;
  final ValueChanged<Map<String, dynamic>>? onBookmarkTap;
  final Listenable? bookmarkChanges;

  @override
  State<HomeMovieCarousel> createState() => _HomeMovieCarouselState();
}

class _HomeMovieCarouselState extends State<HomeMovieCarousel> {
  Widget? _slider;
  String? _configuration;
  Object? _selectedId;
  bool _restored = false;
  String get _storageId => 'home-carousel-selected-${widget.mediaType}';

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
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height =
        widget.height.clamp(300.0, 600.0) + (scale - 1).clamp(0, 2) * 260;
    final configuration = '${widget.mediaType}:$height:$active:'
        '${movies.map((movie) => '${movie['id']}:${catalogueArtwork(movie, backdrop: true)}:${catalogueArtwork(movie)}').join('|')}';
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
          height: height,
          initialPage: initialPage,
          autoPlay: active && movies.length > 1,
          autoPlayInterval: const Duration(seconds: 4),
          autoPlayAnimationDuration: const Duration(milliseconds: 400),
          enableInfiniteScroll: movies.length > 1,
          enlargeCenterPage: false,
          viewportFraction: 1,
          onPageChanged: (index, _) {
            if (index >= widget.movies.length) return;
            _selectedId = widget.movies[index]['id'];
            PageStorage.maybeOf(context)
                ?.writeState(context, _selectedId, identifier: _storageId);
          },
        ),
        itemBuilder: (context, index, _) {
          final movie = widget.movies[index];
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _FeaturedTitleCard(
                  key: ValueKey('${widget.mediaType}:${movie['id']}'),
                  movie: movie,
                  isSaved: () => widget.isSaved?.call(movie) ?? false,
                  bookmarkChanges: widget.bookmarkChanges,
                  onBookmarkTap: widget.onBookmarkTap == null
                      ? null
                      : () => widget.onBookmarkTap!(movie),
                  onDetails: () => widget.onMovieTap(movie)));
        },
      );
    }
    return _slider!;
  }
}

class _FeaturedTitleCard extends StatefulWidget {
  const _FeaturedTitleCard(
      {super.key,
      required this.movie,
      required this.isSaved,
      required this.onDetails,
      this.bookmarkChanges,
      this.onBookmarkTap});
  final Map<String, dynamic> movie;
  final bool Function() isSaved;
  final VoidCallback onDetails;
  final VoidCallback? onBookmarkTap;
  final Listenable? bookmarkChanges;

  @override
  State<_FeaturedTitleCard> createState() => _FeaturedTitleCardState();
}

class _FeaturedTitleCardState extends State<_FeaturedTitleCard> {
  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final title =
        (movie['title'] ?? movie['name'] ?? 'Featured title').toString();
    final image = catalogueArtwork(movie, backdrop: true, size: 'w780') ??
        catalogueArtwork(movie);
    final genre = _genres(movie);
    final year =
        '${movie['release_date'] ?? movie['first_air_date'] ?? movie['year'] ?? ''}';
    final date = RegExp(r'^\d{4}').stringMatch(year);
    final runtime = movie['runtime'] ?? movie['runtime_minutes'];
    final minutes = runtime is num ? runtime.toInt() : 0;
    final rating =
        num.tryParse('${movie['vote_average'] ?? movie['rating'] ?? ''}');
    final description =
        (movie['tagline'] ?? movie['overview'] ?? '').toString().trim();
    final metadata = [
      if (date != null) date,
      if (minutes > 0)
        '${minutes ~/ 60 > 0 ? '${minutes ~/ 60}h ' : ''}${minutes % 60}m'
    ];
    return Semantics(
        label: title,
        container: true,
        explicitChildNodes: true,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              GestureDetector(
                  onTap: widget.onDetails,
                  excludeFromSemantics: true,
                  child: SafeNetworkImage(imageUrl: image, fit: BoxFit.cover)),
              const IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [
                    0,
                    0.32,
                    0.64,
                    1
                  ],
                              colors: [
                    Color(0x100B0D10),
                    Color(0x200B0D10),
                    Color(0xD9141414),
                    Color(0xFF141414)
                  ])))),
              Positioned(
                  top: 14,
                  left: 16,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0x80516673),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('TONIGHT’S PICK',
                          style: TextStyle(
                              color: Color(0xFFE3E2E1),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1)))),
              Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (genre.isNotEmpty) ...[
                          Text(genre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: CinemaPalette.homeAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 1.4)),
                          const SizedBox(height: 5),
                        ],
                        Text(title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: 'serif',
                                fontSize:
                                    (MediaQuery.sizeOf(context).width * .074)
                                        .clamp(25, 40),
                                height: 1.05,
                                color: CinemaPalette.ivory,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8)),
                        if (metadata.isNotEmpty ||
                            (rating != null && rating > 0)) ...[
                          const SizedBox(height: 7),
                          Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 7,
                              runSpacing: 3,
                              children: [
                                if (metadata.isNotEmpty)
                                  Text(metadata.join('  ·  '),
                                      style: const TextStyle(
                                          color: Color(0xFFD9D5D3),
                                          fontSize: 12)),
                                if (rating != null && rating > 0)
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            size: 15,
                                            color: CinemaPalette.homeAccent),
                                        const SizedBox(width: 3),
                                        Text(rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                                color: Color(0xFFD9D5D3),
                                                fontSize: 12)),
                                      ]),
                              ]),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFE4D8C9),
                                  fontSize: 13,
                                  height: 1.3)),
                        ],
                        const SizedBox(height: 13),
                        Row(children: [
                          Expanded(
                              child: FilledButton(
                                  onPressed: widget.onDetails,
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: CinemaPalette.ivory,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(9))),
                                  child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                            child: Text('View details',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700))),
                                        SizedBox(width: 9),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 19),
                                      ]))),
                          const SizedBox(width: 10),
                          _CarouselBookmark(
                              isSaved: widget.isSaved,
                              onTap: widget.onBookmarkTap,
                              changes: widget.bookmarkChanges),
                        ]),
                      ])),
            ])));
  }
}

class _CarouselBookmark extends StatefulWidget {
  const _CarouselBookmark({required this.isSaved, this.onTap, this.changes});
  final bool Function() isSaved;
  final VoidCallback? onTap;
  final Listenable? changes;
  @override
  State<_CarouselBookmark> createState() => _CarouselBookmarkState();
}

class _CarouselBookmarkState extends State<_CarouselBookmark> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _CarouselBookmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(_refresh);
      widget.changes?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.isSaved();
    return IconButton(
      onPressed: widget.onTap == null
          ? null
          : () {
              widget.onTap!();
              if (widget.changes == null) _refresh();
            },
      tooltip: saved ? 'Remove from My list' : 'Save to My list',
      isSelected: saved,
      selectedIcon: const Icon(Icons.bookmark_rounded),
      icon: const Icon(Icons.bookmark_border_rounded),
      style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          foregroundColor: CinemaPalette.ivory,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.all(10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
    );
  }
}

String _genres(Map<String, dynamic> movie) {
  final raw = movie['genres'];
  if (raw is List && raw.isNotEmpty) {
    return raw
        .map((genre) => genre is Map ? genre['name'] : genre)
        .whereType<String>()
        .take(2)
        .join(' · ')
        .toUpperCase();
  }
  const names = <int, String>{
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-fi',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    10759: 'Action & Adventure',
    10765: 'Sci-fi & Fantasy'
  };
  return (movie['genre_ids'] is List ? movie['genre_ids'] as List : const [])
      .map((id) => names[id])
      .whereType<String>()
      .take(2)
      .join(' · ')
      .toUpperCase();
}
