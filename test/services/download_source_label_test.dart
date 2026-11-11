import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/utils/download_source_label.dart';

void main() {
  test('download choices distinguish size and language at the same quality',
      () {
    expect(
        downloadSourceLabel(
            {'label': '1080P', 'locale': 'en', 'bytes': '1073741824'}),
        '1080P · en · 1.0 GB');
    expect(
        downloadSourceLabel(
            {'label': '1080P', 'locale': 'fr', 'bytes': '524288000'}),
        '1080P · fr · 500.0 MB');
  });
  test('unknown and invalid metadata do not invent sizes or languages', () {
    expect(downloadSourceLabel({'label': 'Source 1'}), 'Source 1');
    expect(downloadSourceLabel({'label': '720P', 'locale': ' ', 'bytes': '-1'}),
        '720P');
    expect(downloadSourceLabel({'label': '720P', 'bytes': 'invalid'}), '720P');
    expect(downloadSourceLabel({'label': '720P', 'bytes': '0'}), '720P · 0 B');
  });
}
