import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/cinema_palette.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/media_api_service.dart';

class MovieWatchProviders extends StatefulWidget {
  const MovieWatchProviders(
      {super.key,
      required this.movieId,
      this.mediaType = 'movie',
      this.suppliedResults});

  final int movieId;
  final String mediaType;
  final Map<String, dynamic>? suppliedResults;

  @override
  State<MovieWatchProviders> createState() => _MovieWatchProvidersState();
}

class _MovieWatchProvidersState extends State<MovieWatchProviders> {
  late Future<Map<String, dynamic>> _availability;
  late String _region;

  @override
  void initState() {
    super.initState();
    _region = WidgetsBinding.instance.platformDispatcher.locale.countryCode
            ?.toUpperCase() ??
        'KE';
    _availability = _loadAvailability();
  }

  Future<Map<String, dynamic>> _loadAvailability() => widget.suppliedResults !=
          null
      ? Future.value(widget.suppliedResults!)
      : MediaApiService.fetchWatchProviders(widget.movieId,
          mediaType: widget.mediaType);

  @override
  void didUpdateWidget(covariant MovieWatchProviders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId ||
        oldWidget.mediaType != widget.mediaType ||
        oldWidget.suppliedResults != widget.suppliedResults) {
      _availability = _loadAvailability();
    }
  }

  Future<void> _openListing(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null ||
        uri.scheme != 'https' ||
        (uri.host != 'www.themoviedb.org' && uri.host != 'themoviedb.org')) {
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Could not open listing');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the viewing options.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Where to watch',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FutureBuilder<Map<String, dynamic>>(
          future: _availability,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Row(children: [
                const Expanded(
                    child: Text('Availability could not be loaded.')),
                TextButton(
                  onPressed: () => setState(() {
                    _availability = _loadAvailability();
                  }),
                  child: const Text('Retry'),
                ),
              ]);
            }
            final results = snapshot.data ?? const <String, dynamic>{};
            if (!results.containsKey(_region) && results.isNotEmpty) {
              _region = results.containsKey('US')
                  ? 'US'
                  : (results.keys.toList()..sort()).first;
            }
            final regions = {...results.keys, _region}.toList()..sort();
            final rawRegion = results[_region];
            final data = rawRegion is Map ? rawRegion : const {};
            final rawLink = data['link'];
            final link = rawLink is String ? rawLink : '';
            const categories = {
              'flatrate': 'Stream',
              'rent': 'Rent',
              'buy': 'Buy',
              'free': 'Free',
              'ads': 'With ads',
            };
            final groups = <Widget>[];
            for (final category in categories.entries) {
              final rawProviders = data[category.key];
              if (rawProviders is! List) continue;
              final seen = <String>{};
              final providers = rawProviders.whereType<Map>().where((provider) {
                final name = provider['provider_name'];
                return name is String &&
                    name.trim().isNotEmpty &&
                    seen.add('${provider['provider_id'] ?? name}');
              }).toList();
              if (providers.isEmpty) continue;
              groups.add(Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.value,
                          style: const TextStyle(color: CinemaPalette.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final provider in providers)
                          ActionChip(
                            avatar: provider['logo_path'] is String &&
                                    (provider['logo_path'] as String)
                                        .startsWith('/')
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w92${provider['logo_path']}',
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.tv, size: 20),
                                    ),
                                  )
                                : const Icon(Icons.tv, size: 20),
                            label: Text(provider['provider_name'] as String),
                            onPressed:
                                link.isEmpty ? null : () => _openListing(link),
                          ),
                      ]),
                    ]),
              ));
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CinemaPalette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(_region),
                      initialValue: _region,
                      decoration:
                          const InputDecoration(labelText: 'Country / region'),
                      items: [
                        for (final region in regions)
                          DropdownMenuItem(value: region, child: Text(region))
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _region = value);
                      },
                    ),
                    if (groups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('No viewing options listed for $_region.'),
                      ),
                    ...groups,
                    const SizedBox(height: 16),
                    const Text('Availability data: JustWatch via TMDB',
                        style: TextStyle(
                            fontSize: 11, color: CinemaPalette.muted)),
                    if (link.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _openListing(link),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View viewing options'),
                      ),
                  ]),
            );
          },
        ),
      ],
    );
  }
}
