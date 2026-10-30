import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_configuration.dart';

String adFailureDiagnostic(Object error) => error is LoadAdError
    ? 'code=${error.code} domain=${error.domain} message=${error.message}'
    : 'error=${error.runtimeType}';

abstract interface class InterstitialGateway {
  Future<bool> initialize({required bool useTestAds});
  Future<LoadedInterstitial> load(String unitId);
}

abstract interface class LoadedInterstitial {
  Future<void> show({required VoidCallback onShown});
  void dispose();
}

class GoogleInterstitialGateway implements InterstitialGateway {
  @override
  Future<bool> initialize({required bool useTestAds}) async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      debugPrint('Ads unavailable: this platform is not Android or iOS.');
      return false;
    }
    // Google's sample app ID has no publisher consent message configured.
    // Test units serve test inventory; production requests require UMP below.
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
      maxAdContentRating: MaxAdContentRating.t,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
      testDeviceIds: AdConfiguration.fromEnvironment().testDeviceIds,
    ));
    if (useTestAds) {
      await MobileAds.instance.initialize();
      return true;
    }
    final consent = Completer<void>();
    void complete() {
      if (!consent.isCompleted) consent.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        unawaited(ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) debugPrint('Consent form: ${error.errorCode}');
          complete();
        }).catchError((Object _) => complete()));
      },
      (error) => complete(),
    );
    await consent.future;
    if (!await ConsentInformation.instance.canRequestAds()) {
      debugPrint('Ads waiting: consent does not currently allow ad requests.');
      return false;
    }
    await MobileAds.instance.initialize();
    return true;
  }

  @override
  Future<LoadedInterstitial> load(String unitId) {
    final loaded = Completer<LoadedInterstitial>();
    unawaited(InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => loaded.complete(_GoogleInterstitial(ad)),
        onAdFailedToLoad: (error) => loaded.completeError(error),
      ),
    ).catchError((Object error, StackTrace stack) {
      if (!loaded.isCompleted) loaded.completeError(error, stack);
    }));
    return loaded.future;
  }
}

class _GoogleInterstitial implements LoadedInterstitial {
  _GoogleInterstitial(this.ad);
  final InterstitialAd ad;
  @override
  Future<void> show({required VoidCallback onShown}) async {
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) closed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onShown(),
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial presentation failed: ${error.code}');
        finish();
      },
    );
    await ad.show();
    await closed.future;
  }

  @override
  void dispose() => unawaited(ad.dispose());
}
