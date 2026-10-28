import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/http_diagnostics.dart';

void main() {
  late DebugPrintCallback originalDebugPrint;
  late List<String> lines;
  setUp(() {
    originalDebugPrint = debugPrint;
    lines = [];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
  });
  tearDown(() => debugPrint = originalDebugPrint);

  test('correlates Flutter requests using backend-generated trace IDs', () {
    const requestId = '11111111-1111-4111-8111-111111111111';
    const instance = '22222222-2222-4222-8222-222222222222';
    logHttpDiagnostic(endpoint: '/api/mobile/details', status: 401, headers: {
      'x-moviehub-response-source': 'films365',
      'x-moviehub-request-id': requestId,
      'x-moviehub-backend-instance': instance,
      'authorization': 'private-key',
      'location': 'https://example.com/movie?token=private-link',
    });
    expect(lines.single, contains('requestId=$requestId'));
    expect(lines.single, contains('backendInstance=$instance'));
    expect(lines.single, contains('source=films365'));
    expect(lines.single, isNot(contains('private')));
    expect(lines.single, isNot(contains('https://')));
  });

  test('does not log arbitrary trace header values', () {
    logHttpDiagnostic(endpoint: '/api/mobile/details', status: 200, headers: {
      'x-moviehub-request-id': 'https://example.com?token=secret',
      'x-moviehub-backend-instance': 'private-key',
      'x-moviehub-response-source': 'private-source',
    });
    expect(
        lines.single, 'endpoint=/api/mobile/details status=200 source=unknown');
  });
}
