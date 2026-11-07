import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/utils/home_catalogue_rows.dart';

void main() {
  test('featured movies and category cards never share a title', () {
    final categories = <String, List<Map<String, dynamic>>>{
      'Trending Today': [
        for (var id = 1; id <= 8; id++) {'id': id}
      ],
      'Top Rated': [
        {'id': 1},
        {'id': 6},
        {'id': 9}
      ],
      'Popular Movies': [
        {'id': 3},
        {'id': 9},
        {'id': 10}
      ],
    };
    final layout = HomeCatalogueLayout.build(categories);
    expect(layout.featured.map((item) => item['id']), [1, 2, 3, 4, 5]);
    expect(layout.rows['Trending Today']!.map((item) => item['id']), [6, 7, 8]);
    expect(layout.rows['Top Rated']!.single['id'], 9);
    expect(layout.rows['Popular Movies']!.single['id'], 10);
    final all = [
      ...layout.featured,
      ...layout.rows.values.expand((items) => items)
    ];
    expect(all.map((item) => item['id']).toSet(), hasLength(all.length));
    expect(categories['Trending Today'], hasLength(8));
    expect(() => layout.rows['Top Rated']!.clear(), throwsUnsupportedError);
  });

  test('provider IDs, numeric aliases and media spellings resolve to one title',
      () {
    final rows = uniqueHomeRows({
      'Trending Today': [
        {'id': 1, 'wambesha_id': 'mv_ONE'}
      ],
      'Now Playing': [
        {'id': '01', 'wambesha_id': 'mv_ALIAS'}
      ],
      'Top Rated': [
        {'id': 2, 'wambesha_id': 'mv_ALIAS'},
        {'id': 3}
      ],
      'Popular TV Shows': [
        {'id': 1, 'media_type': 'series'}
      ],
      'Top Rated TV Shows': [
        {'id': '1', 'media_type': 'tv'},
        {'id': 2}
      ],
    });
    expect(rows['Trending Today'], hasLength(1));
    expect(rows['Now Playing'], isEmpty);
    expect(rows['Top Rated']!.single['id'], 3);
    expect(rows['Popular TV Shows'], hasLength(1));
    expect(rows['Top Rated TV Shows']!.single['id'], 2);
  });

  test('TV hero owns its titles without removing an unrelated movie', () {
    final categories = <String, List<Map<String, dynamic>>>{
      'Trending Today': [
        {'id': 1}
      ],
      'Popular TV Shows': [
        {'id': 1},
        {'id': 2}
      ],
      'Trending TV Today': [
        {'id': 1}
      ],
    };
    final all = HomeCatalogueLayout.build(categories);
    expect(all.featured.single['id'], 1);
    expect(all.rows['Popular TV Shows'], hasLength(2));
    final tv = HomeCatalogueLayout.build(categories, tvOnly: true);
    expect(tv.featured.single['id'], 1);
    expect(tv.rows.containsKey('Trending Today'), isFalse);
    expect(tv.rows['Popular TV Shows']!.single['id'], 2);
    expect(tv.rows['Trending TV Today'], isEmpty);
  });

  test('display order owns each title regardless of response arrival order',
      () {
    final categories = <String, List<Map<String, dynamic>>>{
      'Top Rated': [
        {'id': 1},
        {'id': 2},
        {'id': 2}
      ],
      'Popular Movies': [
        {'id': 1},
        {'id': 3}
      ],
      'Trending Today': [
        {'id': 1}
      ],
    };
    final rows = uniqueHomeRows(categories);
    expect(rows['Trending Today']!.map((item) => item['id']), [1]);
    expect(rows['Top Rated']!.map((item) => item['id']), [2]);
    expect(rows['Popular Movies']!.map((item) => item['id']), [3]);
    // View All and pagination still have the complete provider pages.
    expect(categories['Top Rated'], hasLength(3));
    expect(categories['Popular Movies'], hasLength(2));
  });

  test('movies and series with the same TMDB number remain separate titles',
      () {
    final rows = uniqueHomeRows({
      'Trending Today': [
        {'id': 1, 'media_type': 'movie'}
      ],
      'Popular TV Shows': [
        {'id': 1, 'media_type': 'tv'}
      ],
      'Trending TV Today': [
        {'id': 1, 'media_type': 'tv'},
        {'id': 2}
      ],
    });
    expect(rows['Trending Today'], hasLength(1));
    expect(rows['Popular TV Shows'], hasLength(1));
    expect(rows['Trending TV Today']!.single['id'], 2);
  });

  test('TV filtering and later pages keep the same title ownership', () {
    final categories = <String, List<Map<String, dynamic>>>{
      'Trending Today': [
        {'id': 1}
      ],
      'Top Rated': [
        {'id': 1},
        {'id': 2}
      ],
      'Popular TV Shows': [
        {'id': 1}
      ],
      'Top Rated TV Shows': [
        {'id': 1},
        {'id': 2}
      ],
    };
    final tvRows = uniqueHomeRows(categories, tvOnly: true);
    expect(tvRows.containsKey('Trending Today'), isFalse);
    expect(tvRows['Top Rated TV Shows']!.single['id'], 2);
    categories['Top Rated']!.addAll([
      {'id': 1},
      {'id': 3}
    ]);
    expect(uniqueHomeRows(categories)['Top Rated']!.map((item) => item['id']),
        [2, 3]);
    // A refreshed first row takes precedence over copies in later rows.
    categories['Trending Today']!.add({'id': 2});
    expect(uniqueHomeRows(categories)['Top Rated']!.single['id'], 3);
  });
}
