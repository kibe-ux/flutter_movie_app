import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/services/wambesha_api_service.dart';
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

  test('source errors provide actionable messages without credentials', () {
    const signedOut = WambeshaRequestException(401);
    const limited = WambeshaRequestException(429);
    expect(movieDownloadErrorMessage(signedOut), contains('sign in again'));
    expect(movieDownloadErrorMessage(limited), contains('limit reached'));
    expect(movieDownloadErrorMessage(signedOut), isNot(contains('API key')));
    expect(
        movieDownloadErrorMessage(const WambeshaSourceUnavailable(
            'No confirmed download file is available for this title.')),
        contains('No confirmed download'));
    expect(movieDownloadErrorDiagnostic(limited),
        'errorType=WambeshaRequestException status=429');
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

  test('invalid response and unavailable movie service are distinct', () {
    expect(
        movieDownloadErrorMessage(const FormatException()), contains('format'));
    expect(movieDownloadErrorMessage(const WambeshaRequestException(503)),
        contains('Movie service'));
  });
}
