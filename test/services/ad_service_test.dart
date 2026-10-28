import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moviehub_app/services/ad_service.dart';
import 'package:moviehub_app/services/interstitial_gateway.dart';
import 'package:moviehub_app/services/ad_free_access.dart';

class _Ad implements LoadedInterstitial {
  final closed = Completer<void>();
  bool shown = false;
  bool disposed = false;
  bool fail = false;
  bool autoClose = false;
  @override
  Future<void> show({required VoidCallback onShown}) async {
    if (fail) throw StateError('Presentation failed');
    shown = true;
    onShown();
    if (!autoClose) await closed.future;
  }

  @override
  void dispose() => disposed = true;
}

class _Gateway implements InterstitialGateway {
  final ads = <_Ad>[];
  bool failLoad = false;
  bool autoClose = false;
  Completer<LoadedInterstitial>? pending;
  int initializations = 0;
  bool initializeReady = true;
  @override
  Future<bool> initialize({required bool useTestAds}) async {
    initializations++;
    return initializeReady;
  }

  @override
  Future<LoadedInterstitial> load(String unitId) async {
    if (failLoad) throw StateError('No fill');
    if (pending != null) return pending!.future;
    final ad = _Ad()..autoClose = autoClose;
    ads.add(ad);
    return ad;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _Gateway gateway;
  late AdService service;
  late DateTime now;
  setUp(() {
    gateway = _Gateway();
    now = DateTime(2026, 10, 24);
    service = AdService.testing(
        gateway: gateway,
        isPremium: () async => false,
        now: () => now,
        warmup: Duration.zero,
        minimumBrowsingActions: 1,
        posterOpensPerAd: 1);
  });
  tearDown(() => service.dispose());

  test(
      'debug builds keep all formats on test ads even with a live environment flag',
      () {
    dotenv.testLoad(
        fileInput:
            'ADMOB_USE_TEST_ADS=false\nADMOB_BANNER_ID=live-banner\nADMOB_INTERSTITIAL_ID=live-interstitial\nADMOB_REWARDED_ID=live-rewarded');
    final originalPlatform = debugDefaultTargetPlatformOverride;
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(service.usesTestAds, isTrue);
      expect(service.bannerAdUnitId, 'ca-app-pub-3940256099942544/9214589741');
      expect(service.interstitialAdUnitId,
          'ca-app-pub-3940256099942544/1033173712');
      expect(
          service.rewardedAdUnitId, 'ca-app-pub-3940256099942544/5224354917');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(service.bannerAdUnitId, 'ca-app-pub-3940256099942544/2435281174');
      expect(service.interstitialAdUnitId,
          'ca-app-pub-3940256099942544/4411468910');
      expect(
          service.rewardedAdUnitId, 'ca-app-pub-3940256099942544/1712485313');
    } finally {
      debugDefaultTargetPlatformOverride = originalPlatform;
      dotenv.clean();
    }
  });

  test('rewarded ad-free pass suppresses interstitials until expiry', () async {
    final access = AdFreeAccess.instance;
    addTearDown(access.clear);
    access.update(
        uid: 'viewer',
        until: now.add(const Duration(hours: 1)),
        serverTime: now);
    await service.init();
    expect(service.canRequestAds, isFalse);
    expect(service.adsSuppressed, isTrue);
    var proceeded = 0;
    await service.onMoviePosterTap(() => proceeded++);
    expect(proceeded, 1);
    expect(gateway.ads, isEmpty);
    access.update(
        uid: 'viewer',
        until: now.subtract(const Duration(seconds: 1)),
        serverTime: now);
    expect(service.canRequestAds, isTrue);
    gateway.autoClose = true;
    service.preloadInterstitial();
    await _flush();
    await service.onMoviePosterTap(() => proceeded++);
    expect(gateway.ads.first.shown, isTrue);
    expect(proceeded, 2);
  });

  test('first poster waits for dismissal, continues once and preloads next',
      () async {
    await service.init();
    await _flush();
    var proceeded = 0;
    final action = service.onMoviePosterTap(() => proceeded++);
    await _flush();
    expect(gateway.ads.single.shown, isTrue);
    expect(proceeded, 0);
    gateway.ads.single.closed.complete();
    await action;
    await _flush();
    expect(proceeded, 1);
    expect(gateway.ads.first.disposed, isTrue);
    expect(gateway.ads.length, 2);
    expect(gateway.initializations, 1);
  });

  test('View All shows without needing poster taps', () async {
    gateway.autoClose = true;
    await service.init();
    await _flush();
    var navigated = false;
    await service.onViewAllTap(() => navigated = true);
    expect(navigated, isTrue);
    expect(gateway.ads.first.shown, isTrue);
    expect(service.moviePosterOpenCount, 0);
  });

  test('poster, download and View All share a cooldown', () async {
    gateway.autoClose = true;
    await service.init();
    await _flush();
    await service.onMoviePosterTap(() {});
    expect(await service.beforeTransition(allowInterstitial: true), isTrue);
    await service.onViewAllTap(() {});
    expect(gateway.ads.where((ad) => ad.shown).length, 1);
    now = now.add(AdService.cooldown);
    await service.onViewAllTap(() {});
    expect(gateway.ads.where((ad) => ad.shown).length, 2);
  });

  test('no fill still continues', () async {
    gateway.failLoad = true;
    await service.init();
    await _flush();
    var proceeded = 0;
    await service.onActionWithAd(() => proceeded++, allowInterstitial: true);
    expect(proceeded, 1);
    expect(gateway.ads, isEmpty);
  });

  test('a long ad starts the cooldown when dismissed', () async {
    await service.init();
    await _flush();
    final action = service.onMoviePosterTap(() {});
    await _flush();
    now = now.add(const Duration(minutes: 2));
    gateway.ads.first.closed.complete();
    await action;
    await _flush();
    expect(await service.beforeTransition(allowInterstitial: true), isTrue);
    expect(gateway.ads.where((ad) => ad.shown).length, 1);
  });

  test('failed presentation disposes ad and continues without a cooldown',
      () async {
    await service.init();
    await _flush();
    gateway.ads.single.fail = true;
    gateway.autoClose = true;
    var proceeded = 0;
    await service.onActionWithAd(() => proceeded++, allowInterstitial: true);
    expect(proceeded, 1);
    expect(gateway.ads.first.disposed, isTrue);
    await _flush();
    await service.onViewAllTap(() => proceeded++);
    expect(gateway.ads.where((ad) => ad.shown).length, 1);
    expect(proceeded, 2);
  });

  test('rapid taps do not overlap ads or duplicate navigation', () async {
    await service.init();
    await _flush();
    var first = 0;
    var second = 0;
    final action = service.onMoviePosterTap(() => first++);
    await _flush();
    await service.onMoviePosterTap(() => second++);
    expect(second, 0);
    gateway.ads.first.closed.complete();
    await action;
    expect(first, 1);
    expect(service.moviePosterOpenCount, 1);
  });

  test('leaving the screen during an ad prevents late navigation', () async {
    await service.init();
    await _flush();
    var active = true;
    var proceeded = false;
    final action =
        service.onViewAllTap(() => proceeded = true, isActive: () => active);
    await _flush();
    active = false;
    gateway.ads.first.closed.complete();
    await action;
    expect(proceeded, isFalse);
  });

  test('slow loading continues and never shows a late ad', () async {
    service.dispose();
    gateway.pending = Completer<LoadedInterstitial>();
    service = AdService.testing(
        gateway: gateway,
        isPremium: () async => false,
        warmup: Duration.zero,
        minimumBrowsingActions: 1,
        posterOpensPerAd: 1);
    await service.init();
    await _flush();
    var proceeded = false;
    await service.onMoviePosterTap(() => proceeded = true);
    expect(proceeded, isTrue);
    final ad = _Ad();
    gateway.pending!.complete(ad);
    await _flush();
    expect(ad.shown, isFalse);
  });

  test('premium user proceeds without initializing ads', () async {
    service.dispose();
    service = AdService.testing(gateway: gateway, isPremium: () async => true);
    expect(await service.beforeTransition(allowInterstitial: true), isTrue);
    expect(gateway.initializations, 0);
  });

  test('failed initialization can recover on the next attempt', () async {
    gateway.initializeReady = false;
    await service.init();
    expect(service.canRequestAds, isFalse);
    expect(gateway.ads, isEmpty);
    gateway.initializeReady = true;
    await service.init();
    await _flush();
    expect(service.canRequestAds, isTrue);
    expect(gateway.initializations, 2);
    expect(gateway.ads, hasLength(1));
  });

  test('premium suppression is explicit and does not request ads', () async {
    service.dispose();
    service = AdService.testing(gateway: gateway, isPremium: () async => true);
    await service.init();
    expect(service.adsSuppressed, isTrue);
    expect(service.canRequestAds, isFalse);
    expect(gateway.initializations, 0);
  });

  test('View All and every third poster have independent ad opportunities',
      () async {
    service.dispose();
    service = AdService.testing(
        gateway: gateway, isPremium: () async => false, now: () => now);
    gateway.autoClose = true;
    await service.init();
    await _flush();
    await service.onMoviePosterTap(() {});
    expect(service.moviePosterOpenCount, 1);
    expect(gateway.ads.where((ad) => ad.shown), isEmpty);
    now = now.add(const Duration(seconds: 60));
    await service.onViewAllTap(() {});
    await _flush();
    expect(gateway.ads.where((ad) => ad.shown), hasLength(1));
    expect(service.moviePosterOpenCount, 1);
    now = now.add(AdService.cooldown);
    await service.onMoviePosterTap(() {});
    expect(service.moviePosterOpenCount, 2);
    expect(gateway.ads.where((ad) => ad.shown), hasLength(1));
    await service.onMoviePosterTap(() {});
    await _flush();
    expect(service.moviePosterOpenCount, 3);
    expect(gateway.ads.where((ad) => ad.shown), hasLength(2));
    now = now.add(AdService.cooldown);
    await service.onMoviePosterTap(() {});
    await service.onMoviePosterTap(() {});
    expect(gateway.ads.where((ad) => ad.shown), hasLength(2));
    await service.onMoviePosterTap(() {});
    expect(service.moviePosterOpenCount, 6);
    expect(gateway.ads.where((ad) => ad.shown), hasLength(3));
  });

  test('generic download and playback actions do not present interstitials',
      () async {
    gateway.autoClose = true;
    await service.init();
    await _flush();
    var proceeded = 0;
    for (var i = 0; i < 5; i++) {
      await service.onActionWithAd(() => proceeded++);
      expect(await service.beforeTransition(), isTrue);
    }
    expect(proceeded, 5);
    expect(gateway.ads.where((ad) => ad.shown), isEmpty);
  });

  test('background browsing transitions never show ads or navigate', () async {
    service.dispose();
    service = AdService.testing(
        gateway: gateway,
        isPremium: () async => false,
        isForeground: () => false,
        warmup: Duration.zero,
        minimumBrowsingActions: 1,
        posterOpensPerAd: 1);
    await service.init();
    await _flush();
    var proceeded = false;
    await service.onMoviePosterTap(() => proceeded = true);
    expect(proceeded, isFalse);
    expect(gateway.ads.where((ad) => ad.shown), isEmpty);
  });

  test('privacy changes dispose pending ads and block presentation', () async {
    gateway.pending = Completer<LoadedInterstitial>();
    await service.init();
    await _flush();
    service.beginPrivacyUpdate();
    expect(service.canRequestAds, isFalse);
    var proceeded = false;
    await service.onViewAllTap(() => proceeded = true);
    expect(proceeded, isTrue);
    final staleAd = _Ad();
    gateway.pending!.complete(staleAd);
    await _flush();
    expect(staleAd.disposed, isTrue);
    expect(staleAd.shown, isFalse);
    gateway.pending = null;
    await service.finishPrivacyUpdate();
    await _flush();
    expect(service.canRequestAds, isTrue);
    expect(gateway.ads, hasLength(1));
  });
}
