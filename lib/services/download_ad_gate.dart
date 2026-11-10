import 'package:flutter/material.dart';
import 'ad_service.dart';

/// Presents an eligible interstitial before resolving download sources.
/// Normal ad-free, cooldown and ad-unavailable behavior still applies.
class DownloadAdGate {
  static Future<bool> authorize(BuildContext context) =>
      AdService().beforeTransition(
        isActive: () => context.mounted,
        allowInterstitial: true,
        skipBrowsingWarmup: true,
      );
}
