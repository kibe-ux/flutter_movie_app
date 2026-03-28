import 'quality.dart';

class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.year,
    required this.qualities,
    this.poster,
  });

  final String id;
  final String title;
  final int year;
  final Map<String, Quality> qualities;
  final String? poster;

  factory Movie.fromJson(Map<String, dynamic> json) {
    final rawQualities = (json['qualities'] as Map<String, dynamic>? ?? {});
    final qualities = <String, Quality>{};
    rawQualities.forEach((key, value) {
      qualities[key] = Quality.fromJson((value as Map).cast<String, dynamic>());
    });

    return Movie(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? 'Unknown') as String,
      year: (json['year'] as num?)?.toInt() ?? 0,
      qualities: qualities,
      poster: json['poster'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'year': year,
      'poster': poster,
      'qualities': qualities.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}
