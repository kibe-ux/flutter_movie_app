import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/account_deletion_service.dart';

class _User extends Fake implements User {
  bool? forcedRefresh;
  bool deleted = false;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    forcedRefresh = forceRefresh;
    return 'verified-token';
  }

  @override
  Future<void> delete() async => deleted = true;
}

void main() {
  for (final entry in {200: 'complete', 202: 'pending'}.entries) {
    test('${entry.key} distinguishes finished cleanup from a saved request',
        () async {
      final user = _User();
      final service = AccountDeletionService(
        baseUrl: 'https://example.test/',
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.toString(), 'https://example.test/api/account');
          expect(request.headers['Authorization'], 'Bearer verified-token');
          expect(request.body, isEmpty);
          return http.Response('{"status":"${entry.value}"}', entry.key);
        }),
      );
      expect(await service.request(user), entry.key == 200);
      expect(user.forcedRefresh, isTrue);
      expect(user.deleted, isFalse);
    });
  }

  test('stale authentication requires reauthentication without deleting Auth',
      () async {
    final user = _User();
    final service = AccountDeletionService(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
        service.request(user),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'requires-recent-login')));
    expect(user.deleted, isFalse);
  });

  test(
      'backend failures and malformed results never fall back to login-only deletion',
      () async {
    for (final response in [
      http.Response('{}', 503),
      http.Response('{"status":"unknown"}', 200),
      http.Response('not json', 200)
    ]) {
      final user = _User();
      final service = AccountDeletionService(
          baseUrl: 'https://example.test',
          client: MockClient((_) async => response));
      await expectLater(service.request(user), throwsA(anything));
      expect(user.deleted, isFalse);
    }
  });

  test('credentials are never sent over an insecure endpoint', () async {
    bool called = false;
    final service = AccountDeletionService(
        baseUrl: 'http://example.test',
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }));
    await expectLater(service.request(_User()), throwsStateError);
    expect(called, isFalse);
  });
}
