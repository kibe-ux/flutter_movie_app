import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/widgets/home_movie_carousel.dart';

void main() {
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
    expect(find.byType(Text), findsNothing);
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
    expect(find.byType(Text), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
