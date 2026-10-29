import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'interstitial_gateway.dart';
import 'ad_free_access.dart';
import '../config/ad_configuration.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal()
      : _gateway = GoogleInterstitialGateway(),
        _isPremium = _readPremium,
        _now = DateTime.now,
        _isForeground = _appIsForeground,
        warmup = const Duration(seconds: 60),
        minimumBrowsingActions = 2,
        posterOpensPerAd = 3 {
    _sessionStartedAt = _now();
    AdFreeAccess.instance.addListener(_entitlementChanged);
  }

  @visibleForTesting
  AdService.testing(
      {required InterstitialGateway gateway,
      required Future<bool> Function() isPremium,
      DateTime Function()? now,
      bool Function()? isForeground,
      this.warmup = const Duration(seconds: 60),
      this.minimumBrowsingActions = 2,
      this.posterOpensPerAd = 3})
      : _gateway = gateway,
        _isPremium = isPremium,
        _now = now ?? DateTime.now,
        _isForeground = isForeground ?? (() => true) {
    _sessionStartedAt = _now();
  }

  final InterstitialGateway _gateway;
  final Future<bool> Function() _isPremium;
  final DateTime Function() _now;
  final bool Function() _isForeground;
  static bool _appIsForeground() =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  final Duration warmup;
  final int minimumBrowsingActions;
  final int posterOpensPerAd;
  late final DateTime _sessionStartedAt;
  // Conservative app limits, not universal intervals prescribed by Google.
  static const cooldown = Duration(minutes: 2);
  int _browsingTransitions = 0;
  int _adGeneration = 0;
  bool _privacyUpdating = false;
  final privacyChanges = ValueNotifier<int>(0);
  Future<void>? _initializing;
  Future<void>? _loading;
  LoadedInterstitial? _ad;
  DateTime? _loadedAt;
  DateTime? _lastShown;
  Timer? _retry;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  bool _adsSuppressed = false;
  bool _rewardAdFree = false;
  int _failures = 0;
  int _posterCount = 0;

  bool get canRequestAds =>
      _ready &&
      !_disposed &&
      !_privacyUpdating &&
      !_adsSuppressed &&
      !AdFreeAccess.instance.active;
  bool get adsSuppressed =>
      _adsSuppressed || _disposed || AdFreeAccess.instance.active;
  bool get usesTestAds => _testAds;
  int get moviePosterOpenCount => _posterCount;
  AdConfiguration get _configuration => AdConfiguration.fromEnvironment();
  bool get _testAds => _configuration.useTestAds;
  String get bannerAdUnitId => _configuration.bannerId;
  String get interstitialAdUnitId => _configuration.interstitialId;
  String get rewardedAdUnitId => _configuration.rewardedId;
  static Future<bool> _readPremium() async =>
      AdFreeAccess.instance.active ||
      ((await SharedPreferences.getInstance()).getBool('is_premium_user') ??
          false);

  void _entitlementChanged() {
    if (_disposed) return;
    final active = AdFreeAccess.instance.active;
    if (_rewardAdFree == active) return;
    _rewardAdFree = active;
    _adGeneration++;
    _retry?.cancel();
    _ad?.dispose();
    _ad = null;
    _loading = null;
    _initializing = null;
    _ready = false;
    _adsSuppressed = AdFreeAccess.instance.active;
    privacyChanges.value++;
    if (!_adsSuppressed && !_privacyUpdating) {
      unawaited(init().whenComplete(() {
        if (!_disposed) privacyChanges.value++;
      }));
    }
  }

  Future<void> init() =>
      _privacyUpdating ? Future<void>.value() : _initializing ??= _initialize();

  void beginPrivacyUpdate() {
    _privacyUpdating = true;
    _ready = false;
    _initializing = null;
    _adGeneration++;
    _loading = null;
    _retry?.cancel();
    _ad?.dispose();
    _ad = null;
    privacyChanges.value++;
  }

  Future<void> finishPrivacyUpdate() async {
    _privacyUpdating = false;
    await init();
    if (!_disposed) privacyChanges.value++;
  }

  Future<void> _initialize() async {
    final generation = _adGeneration;
    try {
      if (_disposed) return;
      _adsSuppressed = await _isPremium();
      if (_adsSuppressed) {
        debugPrint('Ads skipped: premium entitlement is enabled.');
        return;
      }
      final ready = await _gateway.initialize(useTestAds: _testAds);
      if (_disposed || _privacyUpdating || generation != _adGeneration) return;
      _ready = ready;
      debugPrint('Ads initialized ready=$_ready '
          'mode=${_testAds ? 'test' : 'production'}');
      if (canRequestAds) preloadInterstitial();
    } catch (error) {
      debugPrint('Ads unavailable: ${error.runtimeType}');
    } finally {
      if (!_ready && generation == _adGeneration) _initializing = null;
    }
  }

  void preloadInterstitial() {
    if (!canRequestAds || _ad != null || _loading != null) return;
    _retry?.cancel();
    _loading = Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final generation = _adGeneration;
    try {
      if (!canRequestAds) return;
      final ad = await _gateway.load(interstitialAdUnitId);
      if (!canRequestAds || generation != _adGeneration) {
        ad.dispose();
        return;
      }
      _ad = ad;
      _loadedAt = _now();
      _failures = 0;
      debugPrint('Ads interstitial loaded.');
    } catch (error) {
      debugPrint('Interstitial load failed: ${adFailureDiagnostic(error)}');
      if (canRequestAds && generation == _adGeneration) {
        _failures = (_failures + 1).clamp(1, 5);
        _retry = Timer(
            Duration(seconds: 15 * (1 << _failures)), preloadInterstitial);
      }
    } finally {
      if (generation == _adGeneration) _loading = null;
    }
  }

  /// Only explicitly eligible browsing transitions can present a preloaded ad.
  /// Downloads, playback and generic actions proceed without an interstitial.
  Future<bool> beforeTransition({
    bool Function()? isActive,
    bool allowInterstitial = false,
    bool isBrowsingTransition = false,
  }) async {
    if (_busy || _disposed) return false;
    _busy = true;
    try {
      if (AdFreeAccess.instance.active || await _isPremium()) return true;
      if (isActive != null && !isActive()) return false;
      if (_privacyUpdating) return true;
      if (!allowInterstitial && !isBrowsingTransition) return true;
      if (!_isForeground()) return false;
      _browsingTransitions++;
      if (!allowInterstitial ||
          _now().difference(_sessionStartedAt) < warmup ||
          _browsingTransitions < minimumBrowsingActions) {
        return true;
      }
      if (_lastShown != null && _now().difference(_lastShown!) < cooldown) {
        return true;
      }
      if (!canRequestAds) {
        unawaited(init());
        return true;
      }
      if (_loadedAt != null &&
          _now().difference(_loadedAt!) >= const Duration(minutes: 55)) {
        _ad?.dispose();
        _ad = null;
      }
      preloadInterstitial();
      if (isActive != null && !isActive()) return false;
      if (!_isForeground()) return false;
      final ad = _ad;
      if (ad == null) return true;
      _ad = null;
      var shown = false;
      try {
        await ad.show(onShown: () {
          shown = true;
          _lastShown = _now();
          _browsingTransitions = 0;
          debugPrint('Ads interstitial shown.');
        });
      } finally {
        if (shown) _lastShown = _now();
        ad.dispose();
        preloadInterstitial();
      }
      return isActive?.call() ?? true;
    } catch (error) {
      debugPrint('Ad skipped: ${error.runtimeType}');
      return isActive?.call() ?? true;
    } finally {
      _busy = false;
    }
  }

  Future<void> onMoviePosterTap(Function onProceed,
      {bool Function()? isActive}) async {
    final nextOpen = _posterCount + 1;
    await onActionWithAd(() {
      _posterCount++;
      onProceed();
    },
        isActive: isActive,
        isBrowsingTransition: true,
        allowInterstitial: nextOpen % posterOpensPerAd == 0);
  }

  Future<void> onViewAllTap(Function onProceed, {bool Function()? isActive}) =>
      onActionWithAd(onProceed, isActive: isActive, allowInterstitial: true);
  Future<void> onActionWithAd(Function onProceed,
      {bool Function()? isActive,
      bool allowInterstitial = false,
      bool isBrowsingTransition = false}) async {
    if (await beforeTransition(
        isActive: isActive,
        allowInterstitial: allowInterstitial,
        isBrowsingTransition: isBrowsingTransition)) {
      if (isActive?.call() ?? true) onProceed();
    }
  }

  @visibleForTesting
  void dispose() {
    AdFreeAccess.instance.removeListener(_entitlementChanged);
    _disposed = true;
    _adGeneration++;
    _retry?.cancel();
    _ad?.dispose();
    _ad = null;
  }
}
