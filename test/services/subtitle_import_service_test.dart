import 'dart:io';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/subtitle_import_service.dart';
import 'package:moviehub_app/services/local_subtitle_service.dart';

void main() {
  late Directory folder;
  late SubtitleImportService service;
  const vtt = 'WEBVTT\n\n00:00:00.000 --> 00:00:30.000\nImported caption\n';
  XFile data(String contents, String name) =>
      XFile.fromData(utf8.encode(contents), name: name, path: name);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('subtitle-import-');
    service = SubtitleImportService(directoryProvider: () async => folder);
  });
  tearDown(() async => folder.delete(recursive: true));
  test(
      'copies arbitrary file names and remembers subtitles for that video only',
      () async {
    final original = File('${folder.path}/unrelated-name.vtt');
    await original.writeAsString(vtt);
    final imported =
        await service.importFile('/movies/Film.mp4', XFile(original.path));
    await original.delete();
    final reopened =
        SubtitleImportService(directoryProvider: () async => folder);
    expect((await reopened.savedFor('/movies/Film.mp4'))?.path, imported.path);
    expect((await LocalSubtitleService.load(imported)).captions.single.text,
        'Imported caption');
    expect(await reopened.savedFor('/movies/Other.mp4'), isNull);
  });
  test('replacement changes formats without leaving a stale preferred track',
      () async {
    final first =
        await service.importFile('/movies/Film.mp4', data(vtt, 'one.vtt'));
    final replacement = await service.importFile('/movies/Film.mp4',
        data('1\n00:00:00,000 --> 00:00:30,000\nReplacement\n', 'two.srt'));
    expect(await first.exists(), isFalse);
    expect(
        (await service.savedFor('/movies/Film.mp4'))?.path, replacement.path);
    expect((await LocalSubtitleService.load(replacement)).captions.single.text,
        'Replacement');
  });
  test('invalid and oversized imports preserve the previous saved track',
      () async {
    final saved =
        await service.importFile('/movies/Film.mp4', data(vtt, 'good.vtt'));
    for (final selected in [
      data(vtt, 'bad.exe'),
      data('not captions', 'bad.vtt'),
      data('x' * (LocalSubtitleService.maxBytes + 1), 'large.srt')
    ]) {
      await expectLater(service.importFile('/movies/Film.mp4', selected),
          throwsFormatException);
      expect((await service.savedFor('/movies/Film.mp4'))?.path, saved.path);
      expect(await saved.readAsString(), vtt);
    }
  });
}
