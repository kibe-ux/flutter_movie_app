import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reporting is available after Firebase initializes on mobile and macOS.
class CrashReportingService {
  static const bool collectionEnabled = bool.fromEnvironment(
    'CRASHLYTICS_ENABLED',
    defaultValue: kReleaseMode,
  );

  static FirebaseCrashlytics? _crashlytics;

  static Future<void> initialize() async {
    if (kIsWeb ||
        !const [
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform) ||
        _crashlytics != null) {
      return;
    }

    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(collectionEnabled);
      _crashlytics = crashlytics;

      final previousHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (previousHandler != null) {
          previousHandler(details);
        } else {
          FlutterError.presentError(details);
        }
        unawaited(recordError(
            details.exception, details.stack ?? StackTrace.current,
            fatal: true, reason: 'Flutter framework error'));
      };

      final previousAsyncHandler = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        if (previousAsyncHandler != null) {
          previousAsyncHandler(error, stack);
        } else {
          FlutterError.presentError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'Uncaught asynchronous error',
          ));
        }
        unawaited(recordError(error, stack,
            fatal: true, reason: 'Uncaught asynchronous error'));
        return true;
      };
    } catch (error) {
      // Reporting must never prevent the app from starting.
      debugPrint('Crashlytics initialization failed: $error');
    }
  }

  /// Use for caught errors that would otherwise never reach a global handler.
  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null || !collectionEnabled) return;
    try {
      await crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
    } catch (reportingError) {
      debugPrint('Crashlytics reporting failed: $reportingError');
    }
  }
}
