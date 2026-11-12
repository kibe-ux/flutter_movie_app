import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/widgets/home_movie_carousel.dart';
import 'package:moviehub_app/widgets/safe_network_image.dart';

void main() {
  testWidgets(
      'bookmark changes on the next frame without rebuilding artwork or Home',
      (tester) async {
    final saved = ValueNotifier(false);
    addTearDown(saved.dispose);
    var homeBuilds = 0;
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (_) {
      homeBuilds++;
      return HomeMovieCarousel(
          movies: const [
            {'id': 1, 'title': 'Instant bookmark'}
          ],
          height: 340,
          isSaved: (_) => saved.value,
          bookmarkChanges: saved,
          onBookmarkTap: (_) => saved.value = !saved.value,
          onMovieTap: (_) {});
    }))));
    await tester.pump();
    final artwork =
        tester.widget<SafeNetworkImage>(find.byType(SafeNetworkImage));
    final slider =
        tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    final controller = slider.pageController;
    final builds = homeBuilds;
    await tester.tap(find.byTooltip('Save to My list'));
    await tester.pump();
    expect(find.byTooltip('Remove from My list'), findsOneWidget);
    expect(homeBuilds, builds);
    expect(
        identical(
            tester.widget<SafeNetworkImage>(find.byType(SafeNetworkImage)),
            artwork),
        isTrue);
    expect(identical(slider.pageController, controller), isTrue);
    saved.value = false;
    await tester.pump();
    expect(find.byTooltip('Save to My list'), findsOneWidget);
    await tester.tap(find.byTooltip('Save to My list'));
    await tester.pump();
    await tester.tap(find.byTooltip('Remove from My list'));
    await tester.pump();
    expect(saved.value, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'featured card shows metadata and separate details/bookmark actions',
      (tester) async {
    var saved = false;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeMovieCarousel(
      movies: const [
        {
          'id': 1,
          'title': 'Interstellar',
          'release_date': '2014-11-07',
          'runtime': 169,
          'vote_average': 8.7,
          'genre_ids': [878, 12],
          'tagline': 'A journey beyond the stars.'
        }
      ],
      height: 340,
      isSaved: (_) => saved,
      onBookmarkTap: (_) => saved = !saved,
      onMovieTap: (_) => opened++,
    ))));
    await tester.pump();
    expect(find.text('TONIGHT’S PICK'), findsOneWidget);
    expect(find.text('INTERSTELLAR'), findsOneWidget);
    expect(find.text('SCI-FI · ADVENTURE'), findsOneWidget);
    expect(find.text('2014  ·  2h 49m'), findsOneWidget);
    expect(find.text('8.7'), findsOneWidget);
    await tester.tap(find.byTooltip('Save to My list'));
    await tester.pump();
    expect(saved, isTrue);
    expect(opened, 0);
    expect(find.byTooltip('Remove from My list'), findsOneWidget);
    await tester.tap(find.text('View details'));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'carousel fits narrow screens with large text and missing metadata',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeMovieCarousel(
          movies: const [
            {
              'id': 1,
              'name': 'A very long featured TV series title',
              'genre_ids': [18, 80],
              'overview':
                  'A longer synopsis to check that the featured card remains readable and the controls fit.'
            }
          ],
          mediaType: 'tv',
          height: 300,
          onMovieTap: (_) {},
        )))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('View details'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('15 supplied posters can all be reached before looping',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeMovieCarousel(
      movies: List.generate(
          15, (index) => {'id': index + 1, 'title': 'Movie ${index + 1}'}),
      height: 220,
      onMovieTap: (_) {},
    ))));
    await tester.pump();
    final slider = tester.widget<CarouselSlider>(find.byType(CarouselSlider));
    expect(slider.itemCount, 15);
    final state =
        tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    final start = state.pageController!.initialPage;
    for (var index = 0; index < 15; index++) {
      state.pageController!.jumpToPage(start + index);
      await tester.pump();
      expect(find.bySemanticsLabel('Movie ${index + 1}'), findsWidgets);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('movie and TV carousels keep separate slide positions',
      (tester) async {
    Widget screen(String type) => MaterialApp(
            home: Scaffold(
          body: HomeMovieCarousel(
            key: ValueKey(type),
            mediaType: type,
            height: 220,
            movies: List.generate(4, (i) => {'id': i + 1, 'media_type': type}),
            onMovieTap: (_) {},
          ),
        ));
    await tester.pumpWidget(screen('movie'));
    await tester.pump();
    var slider = tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    slider.pageController!.jumpToPage(slider.pageController!.initialPage + 2);
    await tester.pump();
    await tester.pumpWidget(screen('tv'));
    await tester.pump();
    slider = tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    expect(slider.options.initialPage, 0);
    slider.pageController!.jumpToPage(slider.pageController!.initialPage + 1);
    await tester.pump();
    await tester.pumpWidget(screen('movie'));
    await tester.pump();
    slider = tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    expect(slider.options.initialPage, 2);
    await tester.pumpWidget(screen('tv'));
    await tester.pump();
    slider = tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    expect(slider.options.initialPage, 1);
    await tester.pumpWidget(const SizedBox());
  });
  final movies = List.generate(
      6,
      (index) => <String, dynamic>{
            'id': index + 1,
            'title': 'Movie ${index + 1}',
          });
  Widget screen(List<Map<String, dynamic>> items) => MaterialApp(
        home: Scaffold(
            body: HomeMovieCarousel(
                movies: items, height: 220, onMovieTap: (_) {})),
      );

  testWidgets(
      'autoplay survives Home rebuilds and all loaded slides precede the loop',
      (tester) async {
    await tester.pumpWidget(screen(movies));
    await tester.pump();
    expect(find.text('View details'), findsWidgets);
    expect(find.byType(AnimatedContainer), findsNothing);
    final state =
        tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    final controller = state.pageController!;
    final start = controller.initialPage;
    expect(controller.page!.round(), start);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page!.round(), start + 1);
    await tester.pumpWidget(screen(List.of(movies)));
    await tester.pump();
    expect(identical(state.pageController, controller), isTrue);
    expect(controller.page!.round(), start + 1);
    for (var index = 2; index < 6; index++) {
      controller.jumpToPage(start + index);
      await tester.pump();
      expect((controller.page!.round() - start) % movies.length, index);
    }
    controller.jumpToPage(start + 6);
    await tester.pump();
    expect((controller.page!.round() - start) % movies.length, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'refresh preserves the selected movie when the feed order changes',
      (tester) async {
    await tester.pumpWidget(screen(movies));
    await tester.pump();
    final state =
        tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    state.pageController!.jumpToPage(state.pageController!.initialPage + 2);
    await tester.pump();
    expect(state.pageController!.page!.round(),
        state.pageController!.initialPage + 2);
    await tester.pumpWidget(screen(movies.reversed.toList()));
    await tester.pump();
    final refreshed =
        tester.state<CarouselSliderState>(find.byType(CarouselSlider));
    expect(refreshed.options.initialPage, 3);
    expect(find.text('View details'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
