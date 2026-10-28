import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/films365_api_service.dart';
import 'package:moviehub_app/utils/movie_download_error.dart';

void main() {
  test('Firebase token expiry gives an actionable sign-in message', () {
    final error = FirebaseAuthException(code: 'user-token-expired');
    expect(movieDownloadErrorMessage(error), contains('Sign out'));
    expect(movieDownloadErrorDiagnostic(error), contains('user-token-expired'));
  });

  test('Firebase network errors do not tell the user to replace the API key',
      () {
    final error = FirebaseAuthException(code: 'network-request-failed');
    expect(movieDownloadErrorMessage(error), contains('connection'));
    expect(movieDownloadErrorMessage(error), isNot(contains('API key')));
    expect(movieDownloadErrorMessage(TimeoutException('network timeout')),
        'Could not reach the download service. Check your connection.');
  });

  test('401 distinguishes Firebase sessions from provider credentials', () {
    const firebase = Films365RequestException(401, source: 'firebase-auth');
    const provider = Films365RequestException(401, source: 'films365');
    expect(movieDownloadErrorMessage(firebase),
        'Please sign in again to download.');
    expect(movieDownloadErrorMessage(firebase), isNot(contains('API key')));
    expect(movieDownloadErrorMessage(provider),
        'Film365 denied access to this movie. Please try again later.');
    expect(movieDownloadErrorMessage(provider), isNot(contains('not set up')));
    expect(movieDownloadErrorMessage(provider), isNot(contains('API key')));
  });

  test('diagnostics do not expose exception messages or unknown codes', () {
    final error = FirebaseAuthException(
      code: 'sensitive-value',
      message: 'private-token-and-download-url',
    );
    expect(movieDownloadErrorDiagnostic(error), contains('code=other'));
    expect(movieDownloadErrorDiagnostic(error),
        isNot(contains('sensitive-value')));
    expect(
        movieDownloadErrorDiagnostic(error), isNot(contains('private-token')));
    const malformed = FormatException('private-token-and-download-url');
    expect(
        movieDownloadErrorDiagnostic(malformed), 'errorType=FormatException');
  });

  test('invalid response and unavailable Firebase configuration are distinct',
      () {
    expect(
        movieDownloadErrorMessage(const FormatException()), contains('format'));
    expect(
        movieDownloadErrorMessage(
            const Films365RequestException(503, source: 'firebase-auth')),
        contains('Firebase configuration'));
  });
}
