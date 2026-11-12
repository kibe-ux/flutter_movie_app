import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/widgets/home_movie_carousel.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('carousel fits $size with text scale $scale and rotation',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(child: Builder(builder: (context) {
            final dimensions = MediaQuery.sizeOf(context);
            final height = dimensions.width > dimensions.height
                ? 300.0
                : (dimensions.width * .88).clamp(300.0, 480.0);
            return HomeMovieCarousel(
                height: height,
                movies: const [
                  {
                    'id': 1,
                    'title':
                        'A very long featured movie title for smaller screens',
                    'genre_ids': [878, 12],
                    'release_date': '2014-11-07',
                    'runtime': 169,
                    'vote_average': 8.7,
                    'overview':
                        'A long synopsis that must remain readable in portrait and landscape without covering the featured label or controls.',
                  }
                ],
                isSaved: (_) => false,
                onBookmarkTap: (_) {},
                onMovieTap: (_) => opened++);
          }))),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final badge = tester.getRect(find.text('TONIGHT’S PICK'));
        final title = tester.getRect(
            find.text('A VERY LONG FEATURED MOVIE TITLE FOR SMALLER SCREENS'));
        expect(title.top, greaterThan(badge.bottom),
            reason: 'Title and badge must not overlap');
        final details = find.widgetWithText(FilledButton, 'View details');
        await tester.ensureVisible(details);
        await tester.tap(details);
        expect(opened, 1);
        final button = tester.getRect(details);
        final bookmark = tester.getRect(find.byTooltip('Save to My list'));
        expect(button.right, lessThanOrEqualTo(bookmark.left));
        expect(bookmark.right, lessThanOrEqualTo(size.width));
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
            tester
                .getRect(find.text(
                    'A VERY LONG FEATURED MOVIE TITLE FOR SMALLER SCREENS'))
                .top,
            greaterThan(tester.getRect(find.text('TONIGHT’S PICK')).bottom));
        await tester.ensureVisible(details);
        await tester.tap(details);
        expect(opened, 2);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
