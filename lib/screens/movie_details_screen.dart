import '../services/tmdb_api.dart';
// -------------------- MovieDetailsScreen.dart --------------------
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/my_list.dart';
import '../utils/movie_download_availability.dart';
import '../utils/movie_download_error.dart';
import '../services/ad_service.dart';
import '../services/download_service.dart';
import '../services/movie_download_service.dart';
import '../services/wambesha_api_service.dart';
import 'video_player_screen.dart';
import '../services/tmdb_details_service.dart';

import '../services/favorites_service.dart';
import 'share_screen.dart';

import '../widgets/safe_network_image.dart';
import '../widgets/movie_hub_banner_ad.dart';
import '../widgets/movie_more_info.dart';
import '../widgets/movie_download_error_notice.dart';
import '../widgets/tv_seasons_section.dart';
import '../services/tv_series_service.dart';

const String imageBase = 'https://image.tmdb.org/t/p/w500';
const String backdropBase = 'https://image.tmdb.org/t/p/w780';

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  const MovieDetailsScreen({super.key, required this.movie});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> similarMovies = [];
  bool isLoadingSimilar = true;
  late DownloadService _downloadService;
  late Future<Map<String, dynamic>?> _tmdbDetails;
  bool _isFavorite = false;
  bool _resolvingDownload = false;
  final _sourceService = WambeshaApiService();
  final _movieFiles = MovieDownloadService();
  final _detailsService = TmdbDetailsService();
  String get _movieSourceId => widget.movie['wambesha_id'] is String
      ? widget.movie['wambesha_id'] as String
      : '${widget.movie['id']}';
  bool get _isTv => isTvSeries(widget.movie);
  String get _mediaType => _isTv ? 'tv' : 'movie';

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService();
    WidgetsBinding.instance.addObserver(this);
    _refreshSavedDownload();
    _tmdbDetails = _loadTmdbDetails();
    fetchSimilarMovies();
    _checkIfFavorite();
    // Resolve the identity early, without requesting metered download links.
    final id = widget.movie['id'];
    if (id is num && id > 0) {
      unawaited(_sourceService
          .resolveTitle(
              tmdbId: id.toInt(),
              type: _mediaType,
              titleRef: _movieSourceId,
              title: (widget.movie['title'] ?? widget.movie['name']) as String?,
              releaseDate: (widget.movie['release_date'] ??
                  widget.movie['first_air_date']) as String?)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}));
    }
  }

  Future<Map<String, dynamic>?> _loadTmdbDetails({bool refresh = false}) async {
    final rawTmdbId = widget.movie['id'];
    if (rawTmdbId is! num) return null;
    final tmdbId = rawTmdbId.toInt();
    if (tmdbId < 1) return null;
    return _detailsService.fetchDetails(
      tmdbId: tmdbId,
      mediaType: _mediaType,
      refresh: refresh,
    );
  }

  @override
  void dispose() {
    _sourceService.dispose();
    _detailsService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSavedDownload();
  }

  void _refreshSavedDownload() {
    if (_isTv) return;
    final rawId = widget.movie['id'];
    if (rawId is! num) return;
    unawaited(_downloadService
        .refreshDownloadStatus(
      movieId: rawId.toInt(),
      movieTitle: widget.movie['title']?.toString() ?? 'Unknown',
      posterPath: widget.movie['poster_path'] is String
          ? widget.movie['poster_path'] as String
          : null,
    )
        .catchError((Object _) {
      if (kDebugMode) {
        debugPrint('endpoint=saved-download-check error=storage-unavailable');
      }
    }));
  }

  // -------------------- Ads --------------------
  void _showInterstitialAd(Function actionAfterAd) {
    AdService().onMoviePosterTap(actionAfterAd,
        isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true));
  }

  void _checkIfFavorite() async {
    final movieId = widget.movie['id'] as int?;
    if (movieId != null) {
      final isFav = await FavoritesService.isFavorite(movieId);
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    }
  }

  void _toggleFavorite() async {
    final movieId = widget.movie['id'] as int?;
    if (movieId == null) return;

    if (_isFavorite) {
      await FavoritesService.removeFromFavorites(movieId);
      if (!mounted) return;
      setState(() => _isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')),
      );
    } else {
      await FavoritesService.addToFavorites(movieId);
      if (!mounted) return;
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to favorites')),
      );
    }
  }

  // -------------------- API Fetch --------------------
  Future<void> fetchSimilarMovies() async {
    try {
      final movieId = widget.movie['id'];
      final response =
          await TmdbApi.get(TmdbApi.uri('$_mediaType/$movieId/similar'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          similarMovies = (data['results'] as List?)
                  ?.take(12)
                  .map((e) =>
                      {...e as Map<String, dynamic>, 'media_type': _mediaType})
                  .toList() ??
              [];
          isLoadingSimilar = false;
        });
      } else {
        setState(() => isLoadingSimilar = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingSimilar = false);
    }
  }

  // -------------------- Helpers --------------------
  Widget buildImage(String? url,
      {double? width,
      double? height,
      BoxFit? fit,
      BorderRadius? borderRadius}) {
    return SafeNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      borderRadius: borderRadius,
    );
  }

  String _getYearFromDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown';
    try {
      return DateTime.parse(date).year.toString();
    } catch (_) {
      return 'Unknown';
    }
  }

  ThemeData get _detailsTheme {
    final theme = Theme.of(context);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: CinemaPalette.gold,
        onPrimary: CinemaPalette.background,
        secondary: CinemaPalette.gold,
        onSecondary: CinemaPalette.background,
        surface: CinemaPalette.surface,
        onSurface: CinemaPalette.ivory,
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        iconColor: CinemaPalette.gold,
        textColor: CinemaPalette.ivory,
      ),
    );
  }

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final backdropUrl = movie['backdrop_path'] != null
        ? '$backdropBase${movie['backdrop_path']}'
        : null;
    final posterUrl = movie['poster_path'] != null
        ? '$imageBase${movie['poster_path']}'
        : null;
    final rating = ((movie['vote_average'] ?? 0.0) as num).toDouble();
    final year =
        _getYearFromDate(movie['release_date'] ?? movie['first_air_date']);
    final duration = movie['runtime'] != null ? '${movie['runtime']} min' : '';

    return Theme(
      data: _detailsTheme,
      child: Scaffold(
        backgroundColor: CinemaPalette.background,
        bottomNavigationBar: const SafeArea(
          top: false,
          child: MovieHubBannerAd(placement: 'movie-details'),
        ),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight:
                  MediaQuery.orientationOf(context) == Orientation.landscape
                      ? 240
                      : 390,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    buildImage(
                      backdropUrl,
                      width: double.infinity,
                      height: 390,
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x330B0A0D),
                            Color(0x6638131F),
                            CinemaPalette.background,
                          ],
                          stops: [0, 0.42, 1],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            CinemaPalette.background.withValues(alpha: 0.32),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: CinemaPalette.background,
              foregroundColor: CinemaPalette.ivory,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: CinemaPalette.background.withValues(alpha: 0.75),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: CinemaPalette.ivory, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CinemaPalette.background.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color:
                          _isFavorite ? CinemaPalette.red : CinemaPalette.ivory,
                      size: 22,
                    ),
                  ),
                  onPressed: _toggleFavorite,
                  tooltip: _isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CinemaPalette.background.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      MyList().contains(movie['id'])
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: MyList().contains(movie['id'])
                          ? const Color(0xFFE50914)
                          : CinemaPalette.ivory,
                      size: 22,
                    ),
                  ),
                  onPressed: () {
                    MyList().toggle(movie['id']);
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CinemaPalette.background.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: CinemaPalette.ivory,
                      size: 22,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShareScreen(movie: {
                          'title': movie['title'] ??
                              movie['name'] ??
                              'Unknown title',
                          'poster_path': movie['poster_path'],
                          'vote_average': movie['vote_average'],
                          'release_date':
                              movie['release_date'] ?? movie['first_air_date'],
                        }),
                      ),
                    );
                  },
                  tooltip: 'Share',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _tmdbDetails,
                      builder: (ctx, snap) => _buildHeaderSection(
                        posterUrl,
                        movie,
                        rating,
                        year,
                        duration,
                        tmdbDetails: snap.data,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildPrimaryActions(movie),
                    const SizedBox(height: 28),
                    _buildOverview(movie),
                    const SizedBox(height: 24),
                    if (movie['id'] is num)
                      MovieMoreInfo(
                        movieId: (movie['id'] as num).toInt(),
                        mediaType: _mediaType,
                        metadata: _tmdbDetails,
                        onRetry: () => setState(() {
                          _tmdbDetails = _loadTmdbDetails(refresh: true);
                        }),
                      ),
                    const SizedBox(height: 24),
                    _buildSimilarMoviesSection(),
                    const SizedBox(height: 28),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Source provided by independent third parties. We do not host or distribute files.',
                        style:
                            TextStyle(fontSize: 10, color: CinemaPalette.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- Sections --------------------
  Widget _buildHeaderSection(
    String? posterUrl,
    Map<String, dynamic> movie,
    double rating,
    String year,
    String duration, {
    Map<String, dynamic>? tmdbDetails,
  }) {
    final details = tmdbDetails ?? const <String, dynamic>{};
    final posterWidth = MediaQuery.sizeOf(context).width < 400 ? 88.0 : 124.0;
    final detailsRuntime = details['runtime'];
    final movieRuntime = _formatRuntime(movie['runtime']);
    final displayDuration = detailsRuntime is num
        ? _formatRuntime(detailsRuntime)
        : (movieRuntime.isNotEmpty ? movieRuntime : duration);
    final detailsRating = details['voteAverage'];
    final displayRating =
        detailsRating is num ? detailsRating.toDouble() : rating;
    final mpaRating =
        details['mpaRating'] is String ? (details['mpaRating'] as String) : '';
    final imdbId =
        details['imdbId'] is String ? (details['imdbId'] as String) : '';
    final genres = _stringList(details['genres']);
    final languages = _stringList(details['spokenLanguages']);
    final productionCompanies =
        _stringList(details['productionCompanies']).take(2).toList();
    final productionCountries =
        _stringList(details['productionCountries']).take(2).toList();
    final releaseDate = _formatFullDate(details['releaseDate']);
    final productionInfo = [
      if (productionCompanies.isNotEmpty) productionCompanies.join(', '),
      if (productionCountries.isNotEmpty) productionCountries.join(', '),
      if (releaseDate.isNotEmpty) releaseDate,
    ].join(' \u00B7 ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: buildImage(posterUrl,
              width: posterWidth, height: posterWidth * 1.5, fit: BoxFit.cover),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: CinemaPalette.wine,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_isTv ? 'TV SERIES' : 'MOVIE',
                    style: const TextStyle(
                        color: CinemaPalette.gold,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800)),
              ),
              Text(
                movie['title'] ?? movie['name'] ?? 'Unknown Title',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  color: CinemaPalette.ivory,
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '\u2605 ${displayRating.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: CinemaPalette.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: GoogleFonts.inter().fontFamily,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: CinemaPalette.muted, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        year,
                        style: const TextStyle(
                            color: CinemaPalette.muted, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              if (displayDuration.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: CinemaPalette.muted, size: 18),
                    const SizedBox(width: 6),
                    Text(displayDuration,
                        style: const TextStyle(
                            color: CinemaPalette.muted, fontSize: 14)),
                  ],
                ),
              ],
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  genres.join(', '),
                  style:
                      const TextStyle(color: CinemaPalette.muted, fontSize: 12),
                ),
              ],
              if (mpaRating.trim().isNotEmpty ||
                  imdbId.trim().isNotEmpty ||
                  languages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (mpaRating.trim().isNotEmpty)
                      Text(
                        mpaRating,
                        style: const TextStyle(
                            color: CinemaPalette.muted, fontSize: 12),
                      ),
                    if (imdbId.trim().isNotEmpty)
                      InkWell(
                        onTap: () => launchUrl(
                          Uri.https('www.imdb.com', '/title/$imdbId'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text(
                          'IMDb',
                          style: TextStyle(
                            color: CinemaPalette.muted,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    if (languages.isNotEmpty)
                      Text(
                        '${languages.take(2).join(', ')}'
                        '${languages.length > 2 ? ' +${languages.length - 2} more' : ''}',
                        style: const TextStyle(
                            color: CinemaPalette.muted, fontSize: 12),
                      ),
                  ],
                ),
              ],
              if (productionInfo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  runSpacing: 4,
                  children: [
                    Text(
                      productionInfo,
                      style: const TextStyle(
                          color: CinemaPalette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatRuntime(Object? rawRuntime) {
    if (rawRuntime is! num) return '';
    final minutes = rawRuntime.toInt();
    if (minutes <= 0) return '';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '${remainingMinutes}m';
    return remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
  }

  String _formatFullDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return '';
    final dateValue = value.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}(?:$|T)').hasMatch(dateValue)) return '';
    final date = DateTime.tryParse(dateValue);
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<({String action, String url})?> _showDownloadOptions(
      BuildContext context, Map<String, dynamic> metadata,
      {String? title, List<Map<String, String>>? qualities}) {
    final displayTitle =
        title ?? widget.movie['title'] ?? widget.movie['name'] ?? 'Movie';
    final availableQualities = qualities ?? const [];
    String selectedUrl = metadata['downloadUrl'] as String? ?? '';
    if (availableQualities.isNotEmpty &&
        !availableQualities.any((q) => q['url'] == selectedUrl)) {
      selectedUrl = availableQualities.first['url']!;
    }
    return showModalBottomSheet<({String action, String url})>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF14171C),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, setSheetState) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Download Options',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose your preferred method to save this file.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF8E95A2),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (availableQualities.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Select Quality',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final q in availableQualities) ...[
                              GestureDetector(
                                onTap: () => setSheetState(
                                    () => selectedUrl = q['url']!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selectedUrl == q['url']
                                        ? CinemaPalette.gold
                                        : const Color(0xFF1C2128),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedUrl == q['url']
                                          ? CinemaPalette.gold
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        selectedUrl == q['url']
                                            ? Icons.check_circle_rounded
                                            : Icons.video_library_outlined,
                                        size: 14,
                                        color: selectedUrl == q['url']
                                            ? Colors.black
                                            : Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        q['label'] ?? 'HD',
                                        style: GoogleFonts.inter(
                                          color: selectedUrl == q['url']
                                              ? Colors.black
                                              : Colors.white,
                                          fontSize: 12,
                                          fontWeight: selectedUrl == q['url']
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildModernOptionTile(
                        icon: Icons.open_in_browser_rounded,
                        iconBg: const Color(0xFF1E293B),
                        iconColor: const Color(0xFF38BDF8),
                        title: 'Download in Browser',
                        subtitle:
                            'Standard download via your default web browser.',
                        onTap: () => Navigator.pop(
                            ctx, (action: 'browser', url: selectedUrl)),
                      ),
                      const SizedBox(height: 12),
                      _buildModernOptionTile(
                        icon: Icons.file_download_outlined,
                        iconBg: const Color(0xFF2C1E1E),
                        iconColor: const Color(0xFFF97316),
                        title: 'Download with ADM',
                        subtitle:
                            'Faster speeds & resume capability using Advanced Download Manager.',
                        onTap: () => Navigator.pop(
                            ctx, (action: 'adm', url: selectedUrl)),
                      ),
                      const SizedBox(height: 12),
                      _buildModernOptionTile(
                        icon: Icons.copy_rounded,
                        iconBg: const Color(0xFF132A26),
                        iconColor: const Color(0xFF34D399),
                        title: 'Copy Download Link',
                        subtitle:
                            'Copy the raw URL to clipboard for external tools.',
                        onTap: () => Navigator.pop(
                            ctx, (action: 'copy', url: selectedUrl)),
                      ),
                    ],
                  ),
                ),
              ),
            ));
  }

  Widget _buildModernOptionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1C2128),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: iconColor.withValues(alpha: 0.12),
        highlightColor: iconColor.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8E95A2),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF555E6D),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAdmDownload(String downloadUrl, String fileName) async {
    // Attempt 1: Direct ADM custom intent scheme (com.dv.adm.AEditor)
    final admIntentUri = Uri.parse(
      'intent:$downloadUrl#Intent;action=android.intent.action.VIEW;'
      'type=video/*;package=com.dv.adm;S.title=${Uri.encodeComponent(fileName)};end',
    );
    try {
      final launched = await launchUrl(
        admIntentUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    // Attempt 2: Fallback to generic URL view with external application chooser
    try {
      final fallbackLaunched = await launchUrl(
        Uri.parse(downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (fallbackLaunched) return;
    } catch (_) {}

    // Attempt 3: If neither opened, offer to install ADM or copy the link
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'ADM not installed or not responding. Link copied to clipboard!'),
        action: SnackBarAction(
          label: 'Get ADM',
          textColor: CinemaPalette.gold,
          onPressed: () => launchUrl(
            Uri.parse(
                'https://play.google.com/store/apps/details?id=com.dv.adm'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
    );
    await _copyDownloadLink(downloadUrl);
  }

  Future<void> _copyDownloadLink(String downloadUrl) async {
    try {
      await Clipboard.setData(ClipboardData(text: downloadUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to copy download link.')),
      );
    }
  }

  Future<void> _openDownloadLink(String downloadUrl) async {
    try {
      final opened = await launchUrl(
        Uri.parse(downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open download link.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open download link.')),
      );
    }
  }

  // -------------------- Primary actions --------------------
  Widget _buildPrimaryActions(Map<String, dynamic> movie) {
    if (_isTv) {
      return TvSeasonsSection(
        seriesId: (movie['id'] as num).toInt(),
        seriesTitle: movie['title'] ?? movie['name'] ?? 'TV Series',
        posterPath: movie['poster_path'],
        metadata: _tmdbDetails,
        onDownload: _startEpisodeDownload,
        onPlay: _playEpisode,
        resolveOnDemand: true,
        onRefresh: () =>
            setState(() => _tmdbDetails = _loadTmdbDetails(refresh: true)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OutlinedButton.icon(
        onPressed: () async {
          final rawId = movie['id'];
          final movieId = rawId is num ? rawId.toInt() : null;
          String? localPath;
          if (movieId != null) {
            localPath = await _downloadService.getDownloadedFilePath(movieId);
          }
          if (!mounted) return;
          final title = movie['title'] ?? movie['name'] ?? 'Movie';
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                    title: title,
                    localFilePath: localPath,
                    videoUrlProvider: localPath != null
                        ? null
                        : (refresh) => _movieFiles.requestPlaybackUrl(
                            movieId: _movieSourceId, refresh: refresh),
                    onGoToDownload: () => _startDownload(movie)),
              ));
        },
        icon: const Icon(Icons.play_circle_outline),
        label: const Text('Watch now'),
      ),
      const SizedBox(height: 12),
      Text('SAVE OFFLINE',
          style: TextStyle(
              color: CinemaPalette.muted,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6)),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: StreamBuilder<Map<int, DownloadItem>>(
            stream: _downloadService.downloadsStream,
            initialData: _downloadService.activeDownloads,
            builder: (context, snapshot) {
              final downloads = snapshot.data ?? {};
              final download = downloads[movie['id']];
              final status = download?.status ?? DownloadStatus.idle;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDownloadButton(
                        movie, status, download?.progress ?? 0),
                    if (status == DownloadStatus.failed &&
                        download?.errorMessage != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(download!.errorMessage!,
                              style: const TextStyle(
                                  color: CinemaPalette.muted, fontSize: 12),
                              textAlign: TextAlign.center)),
                  ]);
            },
          )),
    ]);
  }

  /// Build download button with different states
  Widget _buildDownloadButton(
      Map<String, dynamic> movie, DownloadStatus status, double progress) {
    IconData icon = Icons.download_rounded;
    String label = 'Download Now';
    VoidCallback? onPressed;
    Color buttonColor = CinemaPalette.gold;

    switch (status) {
      case DownloadStatus.idle:
        icon = Icons.download_rounded;
        label = 'Download Now';
        onPressed = () => _startDownload(movie);
        break;
      case DownloadStatus.downloading:
        icon = Icons.pause_rounded;
        label = '${(progress * 100).toStringAsFixed(0)}%';
        onPressed = () => _pauseDownload(movie['id']);
        buttonColor = Colors.orange;
        break;
      case DownloadStatus.paused:
        icon = Icons.play_arrow_rounded;
        label = 'Resume';
        onPressed = () => _resumeDownload(movie['id']);
        buttonColor = Colors.orange;
        break;
      case DownloadStatus.completed:
        icon = Icons.check_rounded;
        label = 'Downloaded';
        onPressed = null; // Disable for downloaded items
        buttonColor = Colors.green;
        break;
      case DownloadStatus.failed:
        icon = Icons.error_rounded;
        label = 'Retry';
        onPressed = () => _startDownload(movie, refreshMetadata: true);
        buttonColor = Colors.red;
        break;
    }

    final isPrimary = status == DownloadStatus.idle;
    return ElevatedButton.icon(
      onPressed: _resolvingDownload ? null : onPressed,
      icon: _resolvingDownload
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon,
              color: isPrimary ? CinemaPalette.background : buttonColor),
      label: Text(_resolvingDownload ? 'Finding download...' : label,
          style: TextStyle(
            color: isPrimary ? CinemaPalette.background : buttonColor,
            fontWeight: FontWeight.w800,
          )),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? CinemaPalette.gold : CinemaPalette.surface,
        side: isPrimary
            ? BorderSide.none
            : BorderSide(color: buttonColor.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        minimumSize: const Size.fromHeight(54),
      ),
    );
  }

  Future<WambeshaSources> _resolveEpisodeSources(int season, int episode,
          {bool refresh = false}) =>
      _sourceService.episodeSources(
        seriesTmdbId: (widget.movie['id'] as num).toInt(),
        seriesRef: widget.movie['wambesha_id'] as String?,
        seriesTitle: (widget.movie['name'] ?? widget.movie['title']) as String?,
        releaseDate: widget.movie['first_air_date'] as String?,
        season: season,
        episode: episode,
        refresh: refresh,
      );

  Future<void> _playEpisode(int season, Map<String, dynamic> episode) async {
    if (isFutureMovieRelease(episode['air_date'])) return;
    final episodeNumber = (episode['episode_number'] as num).toInt();
    final seriesTitle =
        widget.movie['title'] ?? widget.movie['name'] ?? 'TV Series';
    final code =
        'S${season.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')}';
    final title = '$seriesTitle $code';
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
                title: title,
                videoUrlProvider: (refresh) async =>
                    (await _resolveEpisodeSources(season, episodeNumber,
                            refresh: refresh))
                        .requirePlaybackUrl(),
                onGoToDownload: () => _startEpisodeDownload(season, episode))));
  }

  Future<void> _startEpisodeDownload(
      int season, Map<String, dynamic> episode) async {
    if (_resolvingDownload || isFutureMovieRelease(episode['air_date'])) return;
    setState(() => _resolvingDownload = true);
    try {
      final number = (episode['episode_number'] as num).toInt();
      final sources = await _resolveEpisodeSources(season, number);
      final downloadUrl = sources.downloadQualities.isNotEmpty
          ? sources.downloadQualities.first['url']!
          : sources.requireUrl('file_holding');
      final metadata = {'downloadUrl': downloadUrl};
      final code =
          'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';
      final episodeTitle =
          '${widget.movie['title'] ?? widget.movie['name']} $code - ${episode['name'] ?? 'Episode $number'}';

      if (!mounted) return;
      final result = await _showDownloadOptions(context, metadata,
          title: episodeTitle, qualities: sources.downloadQualities);
      if (!mounted || result == null) return;
      final url = result.url;
      final action = result.action;
      if (action == 'copy') {
        await _copyDownloadLink(url);
        return;
      }
      if (action == 'browser') {
        await _openDownloadLink(url);
        return;
      }
      if (action == 'adm') {
        await _openAdmDownload(url, '$episodeTitle.mp4');
        return;
      }
      if (!await AdService().beforeTransition(isActive: () => mounted)) return;
      if (!mounted) return;
      unawaited(_downloadService.downloadMovie(
        movieId: episodeDownloadId((episode['id'] as num).toInt()),
        movieTitle: episodeTitle,
        posterPath: widget.movie['poster_path'],
        downloadUrl: url,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Downloading $code')));
    } catch (error) {
      if (mounted) {
        showMovieDownloadError(context, error);
      }
    } finally {
      if (mounted) setState(() => _resolvingDownload = false);
    }
  }

  /// Start download with API integration
  Future<void> _startDownload(Map<String, dynamic> movie,
      {bool refreshMetadata = false}) async {
    if (_resolvingDownload) {
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _resolvingDownload = true);
    var downloadStage = 'movie-id';
    try {
      final tmdbId = (movie['id'] as num?)?.toInt();
      if (tmdbId == null) {
        throw StateError('Movie is missing a valid TMDB ID.');
      }

      downloadStage = 'wambesha-sources';
      final movieTitle = movie['title'] ?? movie['name'] ?? 'Movie';
      final sources = await _sourceService.movieSources(
        tmdbId: tmdbId,
        titleRef: _movieSourceId,
        title: movieTitle,
        releaseDate: movie['release_date'] as String?,
        refresh: refreshMetadata,
      );
      final downloadUrl = sources.downloadQualities.isNotEmpty
          ? sources.downloadQualities.first['url']!
          : sources.requireUrl('file_holding');
      final metadata = {'downloadUrl': downloadUrl};

      if (!mounted) return;
      downloadStage = 'download-options';
      final result = await _showDownloadOptions(context, metadata,
          title: movieTitle, qualities: sources.downloadQualities);
      if (!mounted || result == null) return;
      final chosenUrl = result.url;
      final action = result.action;
      if (action == 'copy') {
        await _copyDownloadLink(chosenUrl);
        return;
      }
      if (action == 'browser') {
        await _openDownloadLink(chosenUrl);
        return;
      }
      if (action == 'adm') {
        await _openAdmDownload(chosenUrl, '$movieTitle.mp4');
        return;
      }
      downloadStage = 'download-ad';
      if (!await AdService().beforeTransition(isActive: () => mounted)) return;
      if (!mounted) return;
      unawaited(
        _downloadService.downloadMovie(
          movieId: tmdbId,
          movieTitle: movie['title'] ?? 'Unknown',
          posterPath: movie['poster_path'],
          downloadUrl: chosenUrl,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download requested: ${movie['title']}',
              style: const TextStyle(color: CinemaPalette.background)),
          backgroundColor: CinemaPalette.gold,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('endpoint=download-preparation stage=$downloadStage '
            '${movieDownloadErrorDiagnostic(error)}');
      }
      if (!mounted) return;
      showMovieDownloadError(context, error,
          onRetry: () => _startDownload(movie, refreshMetadata: true));
    } finally {
      if (mounted) setState(() => _resolvingDownload = false);
    }
  }

  /// Pause download
  void _pauseDownload(int movieId) {
    _downloadService.pauseDownload(movieId);
  }

  /// Resume download
  void _resumeDownload(int movieId) {
    _downloadService.resumeDownload(movieId);
  }

  // -------------------- Overview --------------------
  Widget _buildOverview(Map<String, dynamic> movie) {
    if (movie['overview'] == null || (movie['overview'] as String).isEmpty) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview',
            style: TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(movie['overview'],
            style: const TextStyle(color: CinemaPalette.muted, fontSize: 14)),
      ],
    );
  }

  // -------------------- Similar Movies --------------------
  Widget _buildSimilarMoviesSection() {
    if (isLoadingSimilar) {
      return const SizedBox(
          height: 200,
          child: Center(
              child: CircularProgressIndicator(color: CinemaPalette.gold)));
    }
    if (similarMovies.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_isTv ? 'More series to explore' : 'More movies to explore',
            style: const TextStyle(
                color: CinemaPalette.ivory,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: similarMovies.length,
            itemBuilder: (context, index) {
              final movie = similarMovies[index];
              final posterUrl = movie['poster_path'] != null
                  ? '$imageBase${movie['poster_path']}'
                  : null;
              return GestureDetector(
                onTap: () {
                  _showInterstitialAd(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MovieDetailsScreen(movie: movie),
                      ),
                    );
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                  color: CinemaPalette.gold),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          )
                        : Container(
                            color: CinemaPalette.surface,
                            child: const Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
