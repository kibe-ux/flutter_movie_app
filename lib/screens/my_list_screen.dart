import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import '../utils/my_list.dart';
import 'movie_details_screen.dart';
import '../services/ad_service.dart';
import '../services/media_api_service.dart';
import '../widgets/cinema_app_bar_surface.dart';
import '../widgets/safe_network_image.dart';

enum _ListSort { newest, title }

class MyListScreen extends StatefulWidget {
  const MyListScreen({
    super.key,
    this.embedded = false,
    this.onBrowse,
    this.initialMovies = const [],
    this.savedList,
    this.loadMovie,
  });

  final bool embedded;
  final VoidCallback? onBrowse;
  final List<Map<String, dynamic>> initialMovies;
  final MyList? savedList;
  final Future<Map<String, dynamic>?> Function(int)? loadMovie;

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final _search = TextEditingController();
  final _removing = <int>{};
  List<Map<String, dynamic>> _movies = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _clearing = false;
  bool _loadFailed = false;
  Set<int> _loadedIds = {};
  _ListSort _sort = _ListSort.newest;
  MyList get _saved => widget.savedList ?? MyList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MyListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = _saved.all;
    if (!_refreshing &&
        (ids.length != _loadedIds.length || !_loadedIds.containsAll(ids))) {
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final cached = {
      for (final movie in [...widget.initialMovies, ..._movies])
        movie['id']: movie,
    };
    final ids = _saved.all.toList().reversed.toList();
    _loadedIds = ids.toSet();
    var failed = false;
    final results = await Future.wait(ids.map((id) async {
      if (!refresh && cached[id] != null) return cached[id];
      try {
        final movie =
            await (widget.loadMovie ?? MediaApiService.fetchMovieDetails)(id);
        if (movie != null && movie['id'] == id) return movie;
      } catch (_) {
        // A single failed title must not hide the rest of the collection.
      }
      failed = true;
      return cached[id];
    }));
    if (!mounted) return;
    setState(() {
      _movies = results
          .whereType<Map<String, dynamic>>()
          .where((movie) => _saved.contains(movie['id'] as int))
          .toList();
      _loading = false;
      _refreshing = false;
      _loadFailed = failed;
    });
  }

  List<Map<String, dynamic>> get _visible {
    final query = _search.text.trim().toLowerCase();
    final movies = _movies
        .where((movie) => _title(movie).toLowerCase().contains(query))
        .toList();
    if (_sort == _ListSort.title) {
      movies.sort(
          (a, b) => _title(a).toLowerCase().compareTo(_title(b).toLowerCase()));
    }
    return movies;
  }

  String _title(Map<String, dynamic> movie) =>
      (movie['title'] ?? movie['name'] ?? 'Untitled').toString();

  void _notice(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: CinemaPalette.surface,
        content: Text(text, style: const TextStyle(color: CinemaPalette.ivory)),
        action: action,
      ));
  }

  Future<void> _remove(Map<String, dynamic> movie) async {
    final id = movie['id'] as int;
    if (_clearing || !_removing.add(id)) return;
    final previous = [..._movies];
    setState(() => _movies.removeWhere((item) => item['id'] == id));
    try {
      if (_saved.contains(id)) await _saved.toggleAndWait(id);
      if (!mounted) return;
      _notice('Removed from My List',
          action: SnackBarAction(
            label: 'Undo',
            textColor: CinemaPalette.homeAccent,
            onPressed: () async {
              if (!_saved.contains(id)) await _saved.toggleAndWait(id);
              if (!mounted) return;
              setState(() {
                if (!_movies.any((item) => item['id'] == id)) {
                  _movies.insert(0, movie);
                }
              });
            },
          ));
    } catch (_) {
      if (mounted) {
        setState(() => _movies = previous);
        _notice('Couldn’t remove this title. Please try again.');
      }
    } finally {
      _removing.remove(id);
    }
  }

  Future<void> _clear() async {
    if (_clearing || _refreshing) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: CinemaPalette.surface,
              title: const Text('Clear My List?',
                  style: TextStyle(color: CinemaPalette.ivory)),
              content: const Text(
                  'Remove all saved titles? This won’t delete any downloaded movies.',
                  style: TextStyle(color: CinemaPalette.muted, height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                        foregroundColor: CinemaPalette.homeAccent),
                    child: const Text('Clear list')),
              ],
            ));
    if (!mounted || confirmed != true) return;
    setState(() => _clearing = true);
    try {
      await _saved.clear();
      if (!mounted) return;
      setState(() {
        _movies.clear();
        _loadFailed = false;
      });
      _notice('My List cleared');
    } catch (_) {
      if (mounted) _notice('Couldn’t clear your list. Please try again.');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _open(Map<String, dynamic> movie) {
    AdService().onMoviePosterTap(() async {
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: movie)));
      if (mounted) await _load();
    }, isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false));
  }

  Widget _empty({bool noMatches = false, bool unavailable = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: CinemaPalette.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: CinemaPalette.homeAccent.withValues(alpha: .2))),
            child: Icon(
                unavailable
                    ? Icons.cloud_off_rounded
                    : noMatches
                        ? Icons.search_off_rounded
                        : Icons.bookmarks_outlined,
                size: 42,
                color: CinemaPalette.homeAccent),
          ),
          const SizedBox(height: 22),
          Text(
              unavailable
                  ? 'Your saved titles are safe'
                  : noMatches
                      ? 'No matching titles'
                      : 'Your next movie night starts here',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: CinemaPalette.ivory,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  height: 1.3)),
          const SizedBox(height: 10),
          Text(
              unavailable
                  ? 'We couldn’t load their details. Check your connection and try again.'
                  : noMatches
                      ? 'Try another title or clear your search.'
                      : 'Tap the bookmark on a movie or show to save it for later.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: CinemaPalette.muted, height: 1.6)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: unavailable
                ? (_refreshing ? null : () => _load(refresh: true))
                : noMatches
                    ? () => setState(_search.clear)
                    : widget.onBrowse ?? () => Navigator.maybePop(context),
            icon: Icon(unavailable
                ? Icons.refresh_rounded
                : noMatches
                    ? Icons.close
                    : Icons.explore_outlined),
            label: Text(unavailable
                ? 'Try again'
                : noMatches
                    ? 'Clear search'
                    : 'Browse Movies'),
            style: FilledButton.styleFrom(
                backgroundColor: CinemaPalette.homeAccent,
                foregroundColor: CinemaPalette.background,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
          ),
        ]),
      );

  Widget _poster(Map<String, dynamic> movie) {
    final title = _title(movie);
    final date =
        (movie['release_date'] ?? movie['first_air_date'] ?? '').toString();
    final year = DateTime.tryParse(date)?.year.toString();
    final type = movie['media_type'] == 'tv' || movie['first_air_date'] != null
        ? 'TV show'
        : 'Movie';
    final poster = movie['poster_path'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
          aspectRatio: .75,
          child: Stack(fit: StackFit.expand, children: [
            Material(
              color: CinemaPalette.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: () => _open(movie),
                  child: Semantics(
                    button: true,
                    label: 'Open $title',
                    child: SafeNetworkImage(
                        imageUrl: poster is String && poster.isNotEmpty
                            ? 'https://image.tmdb.org/t/p/w300$poster'
                            : null),
                  )),
            ),
            Positioned(
                top: 5,
                right: 5,
                child: IconButton.filled(
                  tooltip: 'Remove $title from My List',
                  onPressed: _clearing ? null : () => _remove(movie),
                  style: IconButton.styleFrom(
                      backgroundColor:
                          CinemaPalette.background.withValues(alpha: .9),
                      foregroundColor: CinemaPalette.homeAccent),
                  icon: const Icon(Icons.bookmark_added_rounded, size: 21),
                )),
          ])),
      const SizedBox(height: 9),
      Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: CinemaPalette.ivory,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3)),
      const SizedBox(height: 5),
      Text([type, if (year != null) year].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: CinemaPalette.muted, fontSize: 12, height: 1.4)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final movies = _visible;
    return Scaffold(
      backgroundColor: CinemaPalette.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('My List'),
              foregroundColor: CinemaPalette.appBarText,
              backgroundColor: CinemaPalette.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: const CinemaAppBarSurface(),
            ),
      body: SafeArea(
          top: !widget.embedded,
          child: RefreshIndicator(
            color: CinemaPalette.homeAccent,
            backgroundColor: CinemaPalette.surface,
            onRefresh: () => _load(refresh: true),
            child: LayoutBuilder(builder: (context, constraints) {
              final padding = constraints.maxWidth > 1000
                  ? (constraints.maxWidth - 960) / 2
                  : 20.0;
              final available = constraints.maxWidth - padding * 2;
              final largeText = MediaQuery.textScalerOf(context).scale(13) > 20;
              final columns =
                  (available / (largeText ? 210 : 120)).floor().clamp(1, 8);
              final width = (available - (columns - 1) * 14) / columns;
              final scaler = MediaQuery.textScalerOf(context);
              final height = width / .75 +
                  scaler.scale(13) * 1.3 * 2 +
                  scaler.scale(12) * 1.4 +
                  20;
              return CustomScrollView(
                key: const PageStorageKey('saved-titles'),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                      padding: EdgeInsets.fromLTRB(padding, 24, padding, 20),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('YOUR COLLECTION',
                                  style: TextStyle(
                                      color: CinemaPalette.homeAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.8)),
                              const SizedBox(height: 10),
                              const Text('Saved for a good night.',
                                  style: TextStyle(
                                      color: CinemaPalette.ivory,
                                      fontSize: 27,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25)),
                              const SizedBox(height: 8),
                              Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                        '${_saved.all.length} saved ${_saved.all.length == 1 ? 'title' : 'titles'}',
                                        style: const TextStyle(
                                            color: CinemaPalette.muted,
                                            height: 1.5)),
                                    if (_saved.all.isNotEmpty)
                                      TextButton.icon(
                                          onPressed: _refreshing || _clearing
                                              ? null
                                              : _clear,
                                          style: TextButton.styleFrom(
                                              foregroundColor:
                                                  CinemaPalette.homeAccent),
                                          icon: const Icon(
                                              Icons.playlist_remove_rounded,
                                              size: 19),
                                          label: const Text('Clear list')),
                                  ]),
                              if (_saved.all.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _search,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                      color: CinemaPalette.ivory),
                                  decoration: InputDecoration(
                                      hintText: 'Search your saved titles',
                                      hintStyle: const TextStyle(
                                          color: CinemaPalette.muted),
                                      prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: CinemaPalette.homeAccent),
                                      suffixIcon: _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear search',
                                              onPressed: () =>
                                                  setState(_search.clear),
                                              icon: const Icon(Icons.close)),
                                      filled: true,
                                      fillColor: CinemaPalette.surface,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                              color:
                                                  CinemaPalette.homeAccent))),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: PopupMenuButton<_ListSort>(
                                      tooltip: 'Sort saved titles',
                                      initialValue: _sort,
                                      color: CinemaPalette.surface,
                                      onSelected: (value) =>
                                          setState(() => _sort = value),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: _ListSort.newest,
                                            child: Text('Recently saved',
                                                style: TextStyle(
                                                    color:
                                                        CinemaPalette.ivory))),
                                        PopupMenuItem(
                                            value: _ListSort.title,
                                            child: Text('Title A–Z',
                                                style: TextStyle(
                                                    color:
                                                        CinemaPalette.ivory))),
                                      ],
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.sort_rounded,
                                                    color: CinemaPalette
                                                        .homeAccent,
                                                    size: 18),
                                                const SizedBox(width: 7),
                                                Flexible(
                                                    child: Text(
                                                        _sort ==
                                                                _ListSort.newest
                                                            ? 'Recently saved'
                                                            : 'Title A–Z',
                                                        style: const TextStyle(
                                                            color: CinemaPalette
                                                                .appBarText,
                                                            fontSize: 13))),
                                              ])),
                                    )),
                              ],
                              if (_refreshing)
                                const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: LinearProgressIndicator(
                                        color: CinemaPalette.homeAccent,
                                        minHeight: 2)),
                              if (_loadFailed && _movies.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text(
                                    'Some titles couldn’t refresh. Your saved list is safe.',
                                    style: TextStyle(
                                        color: CinemaPalette.muted,
                                        height: 1.5)),
                                TextButton.icon(
                                    onPressed: _refreshing
                                        ? null
                                        : () => _load(refresh: true),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try again')),
                              ],
                            ]),
                      )),
                  if (!_loading && movies.isEmpty)
                    SliverFillRemaining(
                        hasScrollBody: false,
                        child: _empty(
                            noMatches: _movies.isNotEmpty,
                            unavailable:
                                _saved.all.isNotEmpty && _movies.isEmpty))
                  else if (!_loading)
                    SliverPadding(
                        padding: EdgeInsets.fromLTRB(padding, 0, padding, 28),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 18,
                                  mainAxisExtent: height),
                          delegate: SliverChildBuilderDelegate(
                              (context, index) => KeyedSubtree(
                                  key: ValueKey(movies[index]['id']),
                                  child: _poster(movies[index])),
                              childCount: movies.length),
                        )),
                ],
              );
            }),
          )),
    );
  }
}
