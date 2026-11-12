import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Two checked snapshots keep the previous queue if a process dies mid-write.
/// Lives in app-private storage; signed delivery URLs never leave this folder.
class DownloadQueueStore {
  DownloadQueueStore(this.directory);
  final Future<Directory> Function() directory;
  int _generation = 0;
  Future<void> _writes = Future.value();

  Future<Map<String, dynamic>?> load() async {
    Map<String, dynamic>? latest;
    final root = await directory();
    for (final slot in [0, 1]) {
      try {
        final envelope = jsonDecode(
            await File(p.join(root.path, 'download_queue_$slot.json'))
                .readAsString()) as Map;
        final payload = envelope['payload'] as String;
        final generation = envelope['generation'] as int;
        if (envelope['checksum'] !=
            sha256.convert(utf8.encode(payload)).toString()) {
          continue;
        }
        final body = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        if (body['version'] != 1 || generation < _generation) continue;
        _generation = generation;
        latest = body;
      } on FileSystemException {
        /* Other slot can still be valid. */
      } on FormatException {
        /* Ignore incomplete snapshots. */
      } on TypeError {/* Ignore unsupported snapshots. */}
    }
    return latest;
  }

  Future<void> save(Map<String, dynamic> snapshot) {
    // Encode now, before mutable task maps change again.
    final payload = jsonEncode({'version': 1, ...snapshot});
    final result = _writes.then((_) async {
      final root = await directory();
      await root.create(recursive: true);
      final generation = ++_generation;
      await File(p.join(root.path, 'download_queue_${generation % 2}.json'))
          .writeAsString(
              jsonEncode({
                'generation': generation,
                'payload': payload,
                'checksum': sha256.convert(utf8.encode(payload)).toString()
              }),
              flush: true);
    });
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> get flushed => _writes;
}
