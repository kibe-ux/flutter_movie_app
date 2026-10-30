import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'interstitial_gateway.dart';

/// Developer diagnostics. These entry points cannot launch in release builds.
class AdDiagnostics {
  static Future<void> openOnRequest() async {
    if (kDebugMode && const bool.fromEnvironment('ADMOB_OPEN_AD_INSPECTOR')) {
      await openInspector();
    }
  }

  static Future<void> openInspector() async {
    if (!kDebugMode) return;
    final ready =
        await GoogleInterstitialGateway().initialize(useTestAds: true);
    if (!ready) {
      throw StateError('Ad Inspector requires an Android or iOS device.');
    }
    final closed = Completer<void>();
    MobileAds.instance.openAdInspector((error) {
      if (closed.isCompleted) return;
      if (error == null) {
        closed.complete();
      } else {
        debugPrint(
            'Ad Inspector failed: code=${error.code} domain=${error.domain} message=${error.message}');
        closed.completeError(
            StateError('Ad Inspector: ${error.message ?? error.code}'));
      }
    });
    await closed.future;
  }
}
