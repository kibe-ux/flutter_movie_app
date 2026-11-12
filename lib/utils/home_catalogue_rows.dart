import '../config/home_categories.dart';

/// A single immutable presentation of the feed. Provider pages stay untouched
/// for View All and cursor pagination. The hero and rows share one identity set.
class HomeCatalogueLayout {
  HomeCatalogueLayout._(this.featured, this.rows);

  final List<Map<String, dynamic>> featured;
  final Map<String, List<Map<String, dynamic>>> rows;

  factory HomeCatalogueLayout.build(
      Map<String, List<Map<String, dynamic>>> categories,
      {bool tvOnly = false,
      bool moviesOnly = false,
      int featuredLimit = 5}) {
    assert(!tvOnly || !moviesOnly);
    final seen = <String>{};
    List<Map<String, dynamic>> takeUnique(
        Iterable<Map<String, dynamic>> items, bool tv,
        {int? limit}) {
      final selected = <Map<String, dynamic>>[];
      for (final item in items) {
        if (limit != null && selected.length >= limit) break;
        if ((tvOnly || moviesOnly) && _isTvTitle(item, tv) != tvOnly) continue;
        final keys = _titleKeys(item, tv);
        if (keys.isEmpty) continue;
        final duplicate = keys.any(seen.contains);
        // Remember aliases even for duplicates: a shared TMDB ID can connect
        // two provider IDs, which must not reappear in another category.
        seen.addAll(keys);
        if (!duplicate) selected.add(item);
      }
      return List.unmodifiable(selected);
    }

    final primaryName = tvOnly ? 'Trending TV Today' : 'Trending Today';
    final popularName = tvOnly ? 'Popular TV Shows' : 'Popular Movies';
    final featuredCategories = <String>[
      primaryName,
      popularName,
      for (final category in homeCategories)
        if (category.isTv == tvOnly &&
            category.name != primaryName &&
            category.name != popularName)
          category.name,
    ];
    final primary = categories[primaryName];
    final featured = <Map<String, dynamic>>[
      ...takeUnique(
          primary?.isNotEmpty == true
              ? primary!
              : categories[popularName] ?? [],
          tvOnly,
          limit: featuredLimit),
    ];
    // Extend a short hero without emptying small rows or triggering refills
    // just to replace their posters. Popular feeds can supplement short heroes;
    // other rows keep their first six titles so new pages remain visible there.
    for (final name in featuredCategories) {
      if (featured.length >= featuredLimit) break;
      final candidateKeys = {...seen};
      final candidates = <Map<String, dynamic>>[];
      for (final item in categories[name] ?? <Map<String, dynamic>>[]) {
        if (_isTvTitle(item, tvOnly) != tvOnly) continue;
        final keys = _titleKeys(item, tvOnly);
        final duplicate = keys.any(candidateKeys.contains);
        candidateKeys.addAll(keys);
        if (keys.isNotEmpty && !duplicate) candidates.add(item);
      }
      final retained =
          name == popularName ? ((candidates.length + 1) ~/ 2).clamp(2, 6) : 6;
      final available = (candidates.length - retained)
          .clamp(0, featuredLimit - featured.length);
      featured.addAll(
          takeUnique(candidates.skip(retained), tvOnly, limit: available));
    }
    final rows = <String, List<Map<String, dynamic>>>{};
    for (final category in homeCategories) {
      if (tvOnly && !category.isTv) continue;
      if (moviesOnly && category.isTv) continue;
      rows[category.name] =
          takeUnique(categories[category.name] ?? [], category.isTv);
    }
    return HomeCatalogueLayout._(
        List.unmodifiable(featured), Map.unmodifiable(rows));
  }
}

bool _isTvTitle(Map<String, dynamic> item, bool tvCategory) {
  final ref = item['wambesha_id'];
  if (ref is String && RegExp(r'^(mv|sr)_[A-Za-z0-9]{1,40}$').hasMatch(ref)) {
    return ref.startsWith('sr_');
  }
  final type = item['media_type'];
  return type == null
      ? tvCategory
      : ['tv', 'series', 'mini_series'].contains(type);
}

Set<String> _titleKeys(Map<String, dynamic> item, bool tvCategory) {
  final ref = item['wambesha_id'];
  final validRef =
      ref is String && RegExp(r'^(mv|sr)_[A-Za-z0-9]{1,40}$').hasMatch(ref);
  final mediaType = item['media_type'];
  final tv = validRef
      ? ref.startsWith('sr_')
      : mediaType == 'tv' ||
          mediaType == 'series' ||
          mediaType == 'mini_series' ||
          (mediaType == null && tvCategory);
  final id = int.tryParse('${item['id']}');
  return {
    if (validRef) 'wambesha:$ref',
    if (id != null && id > 0) '${tv ? 'tv' : 'movie'}:$id',
  };
}

Map<String, List<Map<String, dynamic>>> uniqueHomeRows(
        Map<String, List<Map<String, dynamic>>> categories,
        {bool tvOnly = false}) =>
    HomeCatalogueLayout.build(categories, tvOnly: tvOnly, featuredLimit: 0)
        .rows;
