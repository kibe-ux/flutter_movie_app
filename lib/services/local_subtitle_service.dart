import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

class LocalSubtitleService {
  static const maxBytes = 2 * 1024 * 1024;

  /// Movie.vtt / Movie.en.vtt / Movie.srt beside Movie.mp4.
  static Future<List<File>> discover(String videoPath) async {
    final video = File(videoPath);
    final stem = p.basenameWithoutExtension(videoPath).toLowerCase();
    final tracks = <File>[];
    try {
      await for (final entry in video.parent.list(followLinks: false)) {
        if (entry is! File) continue;
        final ext = p.extension(entry.path).toLowerCase();
        if (ext != '.vtt' && ext != '.srt') continue;
        final name = p.basenameWithoutExtension(entry.path).toLowerCase();
        if (name == stem ||
            (name.startsWith('$stem.') &&
                RegExp(r'^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$')
                    .hasMatch(name.substring(stem.length + 1)))) {
          tracks.add(entry);
          if (tracks.length == 32) break;
        }
      }
    } on FileSystemException {
      // Missing/unreadable subtitles must never prevent video playback.
    }
    tracks.sort((a, b) => a.path.compareTo(b.path));
    return tracks;
  }

  static Future<ClosedCaptionFile> load(File file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Subtitle file is too large.');
    }
    final contents = await file.readAsString();
    final captions = p.extension(file.path).toLowerCase() == '.srt'
        ? SubRipCaptionFile(contents)
        : WebVTTCaptionFile(contents);
    if (captions.captions.isEmpty) {
      throw const FormatException('No subtitle cues found.');
    }
    return captions;
  }
}
