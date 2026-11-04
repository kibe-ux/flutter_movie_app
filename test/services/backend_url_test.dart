import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/backend_url.dart';

void main() {
  test('release backends require HTTPS and reject credential-bearing URLs', () {
    expect(validateBackendUrl(' https://backend.test/ ', allowLocalHttp: false),
        'https://backend.test');
    for (final value in [
      'http://backend.test',
      'http://127.0.0.1:3000',
      'https://user:password@backend.test',
      'https://backend.test?token=secret',
      'https://backend.test#fragment',
      'file:///tmp/backend',
      '',
    ]) {
      expect(() => validateBackendUrl(value, allowLocalHttp: false),
          throwsStateError);
    }
  });

  test('debug HTTP is restricted to explicit local development hosts', () {
    expect(validateBackendUrl('http://10.0.2.2:3000', allowLocalHttp: true),
        'http://10.0.2.2:3000');
    expect(
        () => validateBackendUrl('http://backend.test', allowLocalHttp: true),
        throwsStateError);
  });
}
