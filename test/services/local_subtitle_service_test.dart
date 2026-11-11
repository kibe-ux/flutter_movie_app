import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/local_subtitle_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('movie-subtitles-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('discovers matching movie/language sidecars, excluding unrelated files',
      () async {
    for (final name in [
      'Movie.vtt',
      'Movie.en.vtt',
      'Movie.pt-PT.srt',
      'Other.vtt',
      'Movie.extra-copy.vtt',
      'Movie.mp4'
    ]) {
      await File(p.join(directory.path, name)).writeAsString('');
    }
    final files = await LocalSubtitleService.discover(
        p.join(directory.path, 'Movie.mp4'));
    expect(files.map((f) => p.basename(f.path)).toSet(),
        {'Movie.vtt', 'Movie.en.vtt', 'Movie.pt-PT.srt'});
  });
  test('parses VTT and SRT cues and rejects empty or oversized files',
      () async {
    final vtt = File(p.join(directory.path, 'Movie.vtt'));
    await vtt.writeAsString('WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nHello\n');
    expect(
        (await LocalSubtitleService.load(vtt)).captions.single.text, 'Hello');
    final srt = File(p.join(directory.path, 'Movie.srt'));
    await srt.writeAsString('1\n00:00:01,000 --> 00:00:03,000\nBonjour\n');
    expect(
        (await LocalSubtitleService.load(srt)).captions.single.text, 'Bonjour');
    await vtt.writeAsString('not subtitles');
    await expectLater(LocalSubtitleService.load(vtt), throwsFormatException);
    await vtt.writeAsString('x' * (LocalSubtitleService.maxBytes + 1));
    await expectLater(LocalSubtitleService.load(vtt), throwsFormatException);
  });
}
