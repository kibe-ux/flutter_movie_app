import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/queued_download_source.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';

WambeshaSources sources(
        {bool expired = false,
        String quality = '720p',
        String url = 'https://delivery.example/file'}) =>
    WambeshaSources.fromJson({
      'sources': [
        {
          'kind': 'file_holding',
          'quality': quality,
          'url': url,
          'expires_at': DateTime.now()
              .add(Duration(hours: expired ? -1 : 1))
              .toIso8601String(),
        }
      ]
    });

void main() {
  test('ambiguous refreshed sources require choosing again', () async {
    final updated = sources(url: 'https://delivery.example/one');
    updated.sources.add(
        {...updated.sources.single, 'url': 'https://delivery.example/two'});
    await expectLater(
        queuedDownloadSource(
            original: sources(expired: true),
            selectedUrl: 'https://delivery.example/file',
            reload: () async => updated),
        throwsA(isA<WambeshaSourceUnavailable>()));
  });
  test('valid queued link spends no source lookup', () async {
    expect(
        await queuedDownloadSource(
            original: sources(),
            selectedUrl: 'https://delivery.example/file',
            reload: () async =>
                throw StateError('Must not request another source')),
        'https://delivery.example/file');
  });
  test('expired queued link reloads once and keeps selected quality', () async {
    var calls = 0;
    final result = await queuedDownloadSource(
        original: sources(expired: true),
        selectedUrl: 'https://delivery.example/file',
        reload: () async {
          calls++;
          return sources(url: 'https://delivery.example/fresh');
        });
    expect(result, 'https://delivery.example/fresh');
    expect(calls, 1);
  });
  test('expired selected quality cannot silently change', () async {
    await expectLater(
        queuedDownloadSource(
            original: sources(expired: true),
            selectedUrl: 'https://delivery.example/file',
            reload: () async => sources(quality: '1080p')),
        throwsA(isA<WambeshaSourceUnavailable>()));
  });
}
