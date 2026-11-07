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
      int featuredLimit = 5}) {
    final seen = <String>{};
    List<Map<String, dynamic>> takeUnique(
        Iterable<Map<String, dynamic>> items, bool tv,
        {int? limit}) {
      final selected = <Map<String, dynamic>>[];
      for (final item in items) {
        if (limit != null && selected.length >= limit) break;
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

    final featured = takeUnique(
        categories[tvOnly ? 'Trending TV Today' : 'Trending Today'] ?? [],
        tvOnly,
        limit: featuredLimit);
    final rows = <String, List<Map<String, dynamic>>>{};
    for (final category in homeCategories) {
      if (tvOnly && !category.isTv) continue;
      rows[category.name] =
          takeUnique(categories[category.name] ?? [], category.isTv);
    }
    return HomeCatalogueLayout._(featured, Map.unmodifiable(rows));
  }
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
