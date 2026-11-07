String? catalogueArtwork(Map<String, dynamic> item,
    {bool backdrop = false, String size = 'w500'}) {
  final url = item[backdrop ? 'backdrop_url' : 'poster_url'];
  if (url is String && url.startsWith('https://')) return url;
  final path = item[backdrop ? 'backdrop_path' : 'poster_path'];
  if (path is! String || path.isEmpty) return null;
  if (path.startsWith('https://')) return path;
  return 'https://image.tmdb.org/t/p/$size$path';
}
