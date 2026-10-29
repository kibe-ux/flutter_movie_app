// -------------------- MovieDetailsScreen.dart --------------------
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/my_list.dart';
import '../utils/movie_download_availability.dart';
import '../utils/movie_download_error.dart';
import '../services/ad_service.dart';
import '../services/download_service.dart';
import '../services/films365_api_service.dart';

import '../services/favorites_service.dart';
import 'share_screen.dart';

import '../widgets/safe_network_image.dart';
import '../widgets/movie_hub_banner_ad.dart';
import '../widgets/movie_more_info.dart';
import '../widgets/movie_download_error_notice.dart';
import '../widgets/tv_seasons_section.dart';
import '../services/tv_series_service.dart';

final String apiKey = dotenv.env['MOVIE_API_KEY'] ?? '';
const String baseUrl = 'https://api.themoviedb.org/3';
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
  static final _sharedInfoService = Films365ApiService();
  List<Map<String, dynamic>> similarMovies = [];
  bool isLoadingSimilar = true;
  late DownloadService _downloadService;
  late final Films365ApiService _films365ApiService;
  late Future<Map<String, dynamic>?> _films365Metadata;
  bool _isFavorite = false;
  bool _resolvingDownload = false;
  bool get _isTv => isTvSeries(widget.movie);
  String get _mediaType => _isTv ? 'tv' : 'movie';

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService();
    WidgetsBinding.instance.addObserver(this);
    _refreshSavedDownload();
    _films365ApiService = _sharedInfoService;
    _films365Metadata = _loadFilms365Metadata();
    fetchSimilarMovies();
    _checkIfFavorite();
  }

  Future<Map<String, dynamic>?> _loadFilms365Metadata({
    bool reportErrors = false,
    bool forDownload = false,
    bool refresh = false,
  }) async {
    try {
      final rawTmdbId = widget.movie['id'];
      if (rawTmdbId is! num) return null;
      final tmdbId = rawTmdbId.toInt();
      if (tmdbId < 1) return null;

      final rawTitle = widget.movie['title'] ?? widget.movie['name'];
      final metadata = await _films365ApiService.findUuidByTmdbId(
        tmdbId: tmdbId,
        type: _mediaType,
        metadataOnly: !forDownload,
        refresh: refresh,
        title: rawTitle is String ? rawTitle : null,
        alternativeTitles: [
          for (final value in [
            widget.movie['original_title'],
            widget.movie['original_name']
          ])
            if (value is String) value,
        ],
        providerId: widget.movie['films365_id'] is String
            ? widget.movie['films365_id'] as String
            : null,
      );
      return metadata;
    } catch (_) {
      if (reportErrors) rethrow;
      return null;
    }
  }

  @override
  void dispose() {
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
      final response = await http.get(
          Uri.parse('$baseUrl/$_mediaType/$movieId/similar?api_key=$apiKey'));
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
                      future: _films365Metadata,
                      builder: (ctx, snap) => _buildHeaderSection(
                        posterUrl,
                        movie,
                        rating,
                        year,
                        duration,
                        films365Details: snap.data,
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
                        metadata: _films365Metadata,
                        onRetry: () => setState(() {
                          _films365Metadata =
                              _loadFilms365Metadata(refresh: true);
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
    Map<String, dynamic>? films365Details,
  }) {
    final details = films365Details ?? const <String, dynamic>{};
    final posterWidth = MediaQuery.sizeOf(context).width < 400 ? 88.0 : 124.0;
    final detailsRuntime = details['runtime'];
    final movieRuntime = _formatRuntime(movie['runtime']);
    final displayDuration = detailsRuntime is num
        ? _formatRuntime(detailsRuntime)
        : (movieRuntime.isNotEmpty ? movieRuntime : duration);
    final detailsRating = details['voteAverage'];
    final displayRating =
        detailsRating is num ? detailsRating.toDouble() : rating;
    final voteCount = details['voteCount'];
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
                    '\u2605 ${displayRating.toStringAsFixed(1)}'
                    '${voteCount is num ? ' (${voteCount.toInt()} votes)' : ''}',
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

  Future<String?> _showDownloadOptions(
      BuildContext context, Map<String, dynamic> metadata) {
    final rawQuality = metadata['quality'];
    final quality = rawQuality is String && rawQuality.trim().isNotEmpty
        ? rawQuality.trim()
        : 'Quality unspecified';
    final rawSize = metadata['size'];
    final size = rawSize is num && rawSize > 0
        ? '${(rawSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : 'Size not supplied';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CinemaPalette.surface,
      showDragHandle: true,
      builder: (ctx) => Theme(
        data: _detailsTheme,
        child: SafeArea(
          child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.download_for_offline_outlined),
                title: Text('Save for offline viewing'),
                subtitle: Text('Review the available download before saving.'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.check_circle, color: CinemaPalette.gold),
                title: const Text('Provider file'),
                subtitle: Text('$quality \u00B7 $size'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                    'One file is available. Other resolutions are not supplied.',
                    style: TextStyle(color: CinemaPalette.muted, fontSize: 12)),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download movie'),
                subtitle: const Text('Save the available file to this device'),
                onTap: () => Navigator.pop(ctx, 'download'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Download Link'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Open in Browser'),
                onTap: () => Navigator.pop(ctx, 'browser'),
              ),
              ListTile(
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          )),
        ),
      ),
    );
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
        metadata: _films365Metadata,
        onDownload: _startEpisodeDownload,
        onRefresh: () => setState(
            () => _films365Metadata = _loadFilms365Metadata(refresh: true)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  Future<void> _startEpisodeDownload(
      int season, Map<String, dynamic> episode) async {
    if (_resolvingDownload || isFutureMovieRelease(episode['air_date'])) return;
    setState(() => _resolvingDownload = true);
    try {
      // Refresh expiring links and match both numbers; never use a series URL.
      final details =
          await _loadFilms365Metadata(reportErrors: true, forDownload: true);
      final number = (episode['episode_number'] as num).toInt();
      final metadata = episodeDownloadMetadata(details, season, number);
      if (!mounted) return;
      if (metadata == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'A download is not currently available for this episode.')));
        return;
      }
      final action = await _showDownloadOptions(context, metadata);
      if (!mounted || action == null) return;
      final url = metadata['downloadUrl'] as String;
      if (action == 'copy') {
        await _copyDownloadLink(url);
        return;
      }
      if (action == 'browser') {
        await _openDownloadLink(url);
        return;
      }
      if (!await AdService().beforeTransition(isActive: () => mounted)) return;
      if (!mounted) return;
      final code =
          'S${season.toString().padLeft(2, '0')}E${number.toString().padLeft(2, '0')}';
      unawaited(_downloadService.downloadMovie(
        movieId: episodeDownloadId((episode['id'] as num).toInt()),
        movieTitle:
            '${widget.movie['title'] ?? widget.movie['name']} $code - ${episode['name'] ?? 'Episode $number'}',
        posterPath: widget.movie['poster_path'],
        downloadUrl: url,
      ));
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

      // Share the page's pending/successful lookup. Retry old, missing or failed
      // links instead of discarding a freshly resolved link on every tap.
      downloadStage = 'authentication-and-details';
      final previousMetadata = _films365Metadata;
      final metadataFuture = () async {
        if (!refreshMetadata) {
          try {
            final metadata = await previousMetadata;
            if (hasRecentMovieDownloadLink(metadata)) return metadata;
          } catch (_) {
            // A failed page lookup can be retried by the download action.
          }
        }
        return _loadFilms365Metadata(reportErrors: true, forDownload: true);
      }();
      setState(() {
        _films365Metadata = metadataFuture;
      });
      final metadata = await metadataFuture;
      if (metadata == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This movie could not be matched in the download catalogue.'),
            showCloseIcon: true,
          ),
        );
        return;
      }
      final downloadUrl = metadata['downloadUrl'];
      if (!hasMovieDownloadLink(metadata)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'The movie provider returned no downloadable file for this movie.'),
              showCloseIcon: true,
            ),
          );
        }
        return;
      }
      final resolvedUrl = (downloadUrl as String).trim();

      if (!mounted) return;
      downloadStage = 'download-options';
      final action = await _showDownloadOptions(context, metadata);
      if (!mounted || action == null) return;
      if (action == 'copy') {
        await _copyDownloadLink(resolvedUrl);
        return;
      }
      if (action == 'browser') {
        await _openDownloadLink(resolvedUrl);
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
          downloadUrl: resolvedUrl,
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
