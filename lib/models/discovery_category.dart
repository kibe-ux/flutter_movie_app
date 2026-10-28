enum CategoryDateRule { none, released, upcoming }

class DiscoveryCategory {
  const DiscoveryCategory(
    this.name,
    this.type,
    this.endpoint, {
    this.filters = const {},
    this.requiredGenres = const [],
    this.dateRule = CategoryDateRule.none,
    this.note,
  });

  final String name;
  final String type;
  final String? endpoint;
  final Map<String, String> filters;
  final List<String> requiredGenres;
  final CategoryDateRule dateRule;
  final String? note;

  Map<String, String> parameters(int page) {
    if (page < 1) {
      throw ArgumentError.value(page, 'page', 'Must be positive.');
    }
    if (endpoint == null) {
      throw StateError('This category has no verified provider mapping.');
    }
    return {'type': type, 'page': '$page', ...filters};
  }
}
