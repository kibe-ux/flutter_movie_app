import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'local_subtitle_service.dart';

class SubtitleImportService {
  SubtitleImportService({Future<Directory> Function()? directoryProvider})
      : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directoryProvider;

  String _key(String videoPath) =>
      sha256.convert(utf8.encode(File(videoPath).absolute.path)).toString();
  Future<Directory> _folder() async => Directory(
      p.join((await _directoryProvider()).path, 'imported_subtitles'));

  Future<File?> savedFor(String videoPath) async {
    final folder = await _folder();
    for (final ext in ['.vtt', '.srt']) {
      final file = File(p.join(folder.path, '${_key(videoPath)}$ext'));
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<File> importFile(String videoPath, XFile selected) async {
    final ext = p.extension(selected.name).toLowerCase();
    if (!['.vtt', '.srt'].contains(ext)) {
      throw const FormatException('Choose a VTT or SRT subtitle file.');
    }
    final bytes = <int>[];
    await for (final chunk in selected.openRead()) {
      if (bytes.length + chunk.length > LocalSubtitleService.maxBytes) {
        throw const FormatException('Subtitle file must be smaller than 2 MB.');
      }
      bytes.addAll(chunk);
    }
    final contents = utf8.decode(bytes);
    final captions = ext == '.srt'
        ? SubRipCaptionFile(contents)
        : WebVTTCaptionFile(contents);
    if (captions.captions.isEmpty) {
      throw const FormatException('No subtitle cues found in this file.');
    }
    final folder = await _folder();
    await folder.create(recursive: true);
    final target = File(p.join(folder.path, '${_key(videoPath)}$ext'));
    final temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    final other = File(p.join(
        folder.path, '${_key(videoPath)}${ext == '.vtt' ? '.srt' : '.vtt'}'));
    if (await other.exists()) await other.delete();
    return target;
  }
}
