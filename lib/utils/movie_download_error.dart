import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/films365_api_service.dart';

String movieDownloadErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    if (error.code == 'network-request-failed') {
      return 'Cannot refresh your sign-in. Check your connection and try again.';
    }
    if (const {
      'user-token-expired',
      'invalid-user-token',
      'user-disabled',
      'user-not-found',
      'no-current-user',
      'requires-recent-login',
    }.contains(error.code)) {
      return 'Your sign-in has expired. Sign out and sign in again to download.';
    }
    return 'Could not verify your sign-in. Please sign out and sign in again.';
  }
  if (error is Films365RequestException) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      if (error.source == 'firebase-auth') {
        return 'Please sign in again to download.';
      }
      if (error.source == 'films365') {
        return 'Film365 denied access to this movie. Please try again later.';
      }
      return 'The download server denied access to this request.';
    }
    if (error.statusCode == 429) {
      return 'Too many download requests. Please wait a moment and try again.';
    }
    if (error.statusCode >= 500) {
      return error.source == 'firebase-auth'
          ? 'The server cannot verify sign-in right now. Its Firebase configuration needs checking.'
          : 'The download server is unavailable. Please try again later.';
    }
  }
  if (error is StateError && error.message.toString().contains('Sign in')) {
    return 'Sign in to download movies.';
  }
  if (error is TimeoutException || error is http.ClientException) {
    return 'Could not reach the download service. Check your connection.';
  }
  if (error is FormatException || error is TypeError) {
    return 'The download information has an unexpected format. Please report this movie.';
  }
  if (error is PlatformException) {
    return 'A device service could not prepare the download. Please restart the app and try again.';
  }
  return 'Could not prepare the download. Please try again.';
}

String movieDownloadErrorDiagnostic(Object error) {
  if (error is FirebaseAuthException) {
    const knownCodes = {
      'network-request-failed',
      'user-token-expired',
      'invalid-user-token',
      'user-disabled',
      'user-not-found',
      'no-current-user',
      'requires-recent-login',
      'internal-error',
      'unknown',
    };
    final code = knownCodes.contains(error.code) ? error.code : 'other';
    return 'errorType=FirebaseAuthException source=firebase-auth code=$code';
  }
  if (error is Films365RequestException) {
    const knownSources = {'firebase-auth', 'films365', 'node-backend'};
    final source =
        knownSources.contains(error.source) ? error.source : 'unknown';
    return 'errorType=Films365RequestException status=${error.statusCode} source=$source';
  }
  return 'errorType=${error.runtimeType}';
}
