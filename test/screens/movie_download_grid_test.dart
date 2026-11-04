import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/models/movie.dart';
import 'package:moviehub_app/models/download_task.dart';
import 'package:moviehub_app/screens/movie_list_screen.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('download grid fits $size at text scale $scale and rotates',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Movie? selected;
        final movies = List.generate(
            20,
            (index) => Movie(
                  id: '$index',
                  title: 'A long movie title that needs multiple lines',
                  year: 2024,
                  qualities: const {},
                ));
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
              body: MovieDownloadGrid(
            movies: movies,
            taskForMovie: (movie) => DownloadTask(
              id: movie.id,
              movieId: movie.id,
              movieTitle: movie.title,
              movieYear: movie.year,
              quality: '1080p',
              savePath: '',
              status: DownloadTaskStatus.downloading,
              progress: .42,
            ),
            onMovieTap: (movie) => selected = movie,
          )),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('Downloading 42%'), findsWidgets);
        await tester.ensureVisible(find.text('Downloading 42%').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Downloading 42%').first);
        expect(selected, same(movies.first));
        final first = tester.getRect(find.byType(InkWell).first);
        final second = tester.getRect(find.byType(InkWell).at(1));
        if (size.width >= 844) {
          expect(second.top, first.top);
          expect(first.width, lessThan(300));
        }
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
