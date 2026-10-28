import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';
import 'interstitial_gateway.dart';

abstract interface class RewardedGateway {
  Future<RewardedVideo> load(String unitId);
}

abstract interface class RewardedVideo {
  Future<bool> show({required String uid, required String sessionId});
  void dispose();
}

class GoogleRewardedGateway implements RewardedGateway {
  @override
  Future<RewardedVideo> load(String unitId) async {
    final ads = AdService();
    await ads.init();
    if (!ads.canRequestAds) {
      throw StateError(
          'A rewarded ad is not available right now. Please try later.');
    }
    final loaded = Completer<RewardedVideo>();
    final consentGeneration = ads.privacyChanges.value;
    bool expired = false;
    unawaited(RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (expired) {
            unawaited(ad.dispose());
            return;
          }
          loaded.complete(_GoogleRewardedVideo(ad, consentGeneration));
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad load failed: ${adFailureDiagnostic(error)}');
          if (!loaded.isCompleted) {
            loaded.completeError(StateError(
                'No rewarded ad is available right now. Please try later.'));
          }
        },
      ),
    ).catchError((Object error) {
      if (!loaded.isCompleted) loaded.completeError(error);
    }));
    return loaded.future.timeout(const Duration(seconds: 30), onTimeout: () {
      expired = true;
      throw StateError('The ad took too long to load. Please try later.');
    });
  }
}

class _GoogleRewardedVideo implements RewardedVideo {
  _GoogleRewardedVideo(this.ad, this.consentGeneration);
  final RewardedAd ad;
  final int consentGeneration;
  @override
  Future<bool> show({required String uid, required String sessionId}) async {
    final closed = Completer<bool>();
    bool earned = false;
    void finish() {
      if (!closed.isCompleted) closed.complete(earned);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, __) => finish(),
    );
    await ad.setServerSideOptions(ServerSideVerificationOptions(
      userId: uid,
      customData: sessionId,
    ));
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        !AdService().canRequestAds ||
        AdService().privacyChanges.value != consentGeneration) {
      throw StateError('Return to Cinema Rewards and try again.');
    }
    await ad.show(onUserEarnedReward: (_, __) {
      earned = true;
    });
    return closed.future;
  }

  @override
  void dispose() => unawaited(ad.dispose());
}
