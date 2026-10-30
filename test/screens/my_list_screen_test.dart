import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/screens/my_list_screen.dart';
import 'package:moviehub_app/utils/my_list.dart';

class _Saved extends Fake implements MyList {
  _Saved(Iterable<int> ids) : ids = ids.toSet();
  final Set<int> ids;
  @override
  Set<int> get all => {...ids};
  @override
  bool contains(int id) => ids.contains(id);
  @override
  Future<void> toggleAndWait(int id) async {
    if (!ids.remove(id)) ids.add(id);
  }

  @override
  Future<void> clear() async => ids.clear();
}

const titles = <Map<String, dynamic>>[
  {'id': 1, 'title': 'Zebra', 'release_date': '2020-01-01'},
  {'id': 2, 'title': 'Alpha', 'release_date': '2022-01-01'},
];

void main() {
  Future<void> open(
    WidgetTester tester,
    _Saved saved, {
    List<Map<String, dynamic>> seed = titles,
    Future<Map<String, dynamic>?> Function(int)? load,
    Size size = const Size(430, 900),
    double scale = 1,
    VoidCallback? onBrowse,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: MyListScreen(
          savedList: saved,
          initialMovies: seed,
          loadMovie: load ?? (_) async => null,
          onBrowse: onBrowse),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'loads saved titles outside the home feed without refetching cached titles',
      (tester) async {
    final calls = <int>[];
    await open(tester, _Saved([1, 2]), seed: [titles.first], load: (id) async {
      calls.add(id);
      return titles.last;
    });
    expect(calls, [2]);
    expect(find.text('Zebra'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('2 saved titles'), findsOneWidget);
  });

  testWidgets('search and title sorting leave the saved collection intact',
      (tester) async {
    final saved = _Saved([2, 1]);
    await open(tester, saved);
    List<String?> orderedTitles() => tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => ['Zebra', 'Alpha'].contains(text))
        .toList();
    expect(orderedTitles(), ['Zebra', 'Alpha']);
    await tester.tap(find.byTooltip('Sort saved titles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Title A–Z'));
    await tester.pumpAndSettle();
    expect(orderedTitles(), ['Alpha', 'Zebra']);
    await tester.enterText(find.byType(TextField), 'alp');
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Zebra'), findsNothing);
    expect(saved.ids, {1, 2});
    await tester.enterText(find.byType(TextField), 'not in list');
    await tester.pumpAndSettle();
    expect(find.text('No matching titles'), findsOneWidget);
  });

  testWidgets(
      'retained collection picks up externally saved titles without refetching known ones',
      (tester) async {
    final saved = _Saved([1]);
    final calls = <int>[];
    Widget screen() => MaterialApp(
            home: MyListScreen(
          savedList: saved,
          initialMovies: [titles.first],
          loadMovie: (id) async {
            calls.add(id);
            return titles.last;
          },
        ));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    saved.ids.add(2);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Zebra'), findsOneWidget);
    expect(calls, [2]);
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(calls, [2]);
  });

  testWidgets('removal can be undone and clear requires confirmation',
      (tester) async {
    final saved = _Saved([1, 2]);
    await open(tester, saved);
    await tester.tap(find.byTooltip('Remove Zebra from My List'));
    await tester.pumpAndSettle();
    expect(saved.ids, {2});
    expect(find.text('Zebra'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(saved.ids, {1, 2});
    expect(find.text('Zebra'), findsOneWidget);
    await tester.tap(find.text('Clear list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved.ids, {1, 2});
    await tester.tap(find.text('Clear list'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear list').last);
    await tester.pumpAndSettle();
    expect(saved.ids, isEmpty);
    expect(find.text('Your next movie night starts here'), findsOneWidget);
  });

  testWidgets(
      'failed details show retry instead of claiming the saved list is empty',
      (tester) async {
    final saved = _Saved([1]);
    var fail = true;
    await open(tester, saved,
        seed: [], load: (_) async => fail ? null : titles.first);
    expect(find.text('Your saved titles are safe'), findsOneWidget);
    expect(saved.ids, {1});
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Zebra'), findsOneWidget);
  });

  testWidgets('empty collection provides a working browse action',
      (tester) async {
    var browsed = false;
    await open(tester, _Saved([]), onBrowse: () => browsed = true);
    await tester.tap(find.text('Browse Movies'));
    expect(browsed, isTrue);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('saved grid fits $size with large text', (tester) async {
      await open(tester, _Saved([1, 2]), size: size, scale: 2);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
