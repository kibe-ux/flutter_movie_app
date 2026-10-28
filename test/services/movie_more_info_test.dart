import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/models/movie_more_info.dart';

void main() {
  test('featured videos are limited to three with official trailers first', () {
    final videos = MovieInfoVideo.featuredFromDetails({
      'videos': [
        {
          'site': 'YouTube',
          'key': 'aaaaaaaaaa0',
          'name': 'Clip',
          'type': 'Clip',
          'official': true
        },
        {
          'site': 'YouTube',
          'key': 'aaaaaaaaaa1',
          'name': 'Fan trailer',
          'type': 'Trailer'
        },
        {
          'site': 'YouTube',
          'key': 'aaaaaaaaaa2',
          'name': 'First official trailer',
          'type': 'Trailer',
          'official': true
        },
        {
          'site': 'YouTube',
          'key': 'aaaaaaaaaa3',
          'name': 'Second official trailer',
          'type': 'Trailer',
          'official': true
        },
        {
          'site': 'YouTube',
          'key': 'aaaaaaaaaa4',
          'name': 'Teaser',
          'type': 'Teaser'
        },
        {
          'site': 'YouTube',
          'key': 'aaaaaaaaaa2',
          'name': 'Duplicate',
          'type': 'Trailer'
        },
      ]
    });
    expect(videos.map((video) => video.name),
        ['First official trailer', 'Second official trailer', 'Fan trailer']);
    expect(videos.first.embedUri.host, 'www.youtube.com');
    expect(videos.first.embedUri.path, startsWith('/embed/'));
    expect(videos.first.embedUri.queryParameters['origin'],
        'https://com.moviehub.app');
  });
  test('uses Details videos and never treats the movie file URL as a trailer',
      () {
    final videos = MovieInfoVideo.fromDetails({
      'videoUrl': 'https://example.com/full-movie.mp4',
      'downloadUrl': 'https://example.com/download',
      'videos': [
        {
          'site': 'YouTube',
          'key': 'abcdefghijk',
          'name': 'Behind the scenes',
          'type': 'Featurette'
        },
        {
          'site': 'Vimeo',
          'key': '123456',
          'name': 'Official trailer',
          'type': 'Trailer'
        },
        {'site': 'YouTube', 'key': 'abcdefghijk', 'name': 'Duplicate'},
        {'site': 'YouTube', 'key': 'bad/key'},
        {'site': 'Unknown', 'key': 'abcdefghijk'},
      ],
    });
    expect(videos.map((video) => video.name),
        ['Official trailer', 'Behind the scenes']);
    expect(videos.first.uri.toString(), 'https://vimeo.com/123456');
    expect(videos.last.youtubeKey, 'abcdefghijk');
    expect(
        MovieInfoVideo.fromDetails({'videoUrl': 'https://example.com/movie'}),
        isEmpty);
  });

  test('handles nested videos and missing Details arrays', () {
    expect(MovieInfoVideo.fromDetails({}), isEmpty);
    final videos = MovieInfoVideo.fromDetails({
      'videos': {
        'results': [
          {'site': 'YouTube', 'key': 'abcdefghijk', 'type': 'Teaser'},
        ]
      }
    });
    expect(videos.single.name, 'Teaser');
    expect(movieInfoRecords(null), isEmpty);
    expect(
        movieInfoRecords([
          null,
          'bad',
          {'name': 'Actor'}
        ]).single['name'],
        'Actor');
    expect(
        movieInfoNames([
          'Action',
          {'name': 'Drama'},
          'Action',
          null,
          ''
        ]),
        ['Action', 'Drama']);
  });
}
