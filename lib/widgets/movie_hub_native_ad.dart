import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../utils/cinema_palette.dart';

/// One SDK-rendered, attributed native card below the saved collection.
class MovieHubNativeAd extends StatefulWidget {
  const MovieHubNativeAd({super.key});

  @override
  State<MovieHubNativeAd> createState() => _MovieHubNativeAdState();
}

class _MovieHubNativeAdState extends State<MovieHubNativeAd>
    with WidgetsBindingObserver {
  NativeAd? _ad;
  Timer? _retry;
  int _generation = 0;
  int _failures = 0;
  bool _loaded = false;
  bool _loading = false;
  bool _active = false;
  bool _foreground = true;
  bool _wideEnough = false;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  bool _current(int generation) => mounted && generation == _generation;
  bool get _eligible => _supported && _active && _foreground && _wideEnough;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdService().privacyChanges.addListener(_privacyChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    if (!_active) _retry?.cancel();
    _queueLoad();
  }

  void _queueLoad() {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current(generation)) unawaited(_load(generation));
    });
  }

  void _privacyChanged() {
    if (!mounted) return;
    _generation++;
    _retry?.cancel();
    _failures = 0;
    _loading = false;
    final old = _ad;
    setState(() {
      _ad = null;
      _loaded = false;
    });
    // Unmount the platform view before disposing its ad.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
    _queueLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _retry?.cancel();
    } else {
      _queueLoad();
    }
  }

  void _scheduleRetry(int generation) {
    if (!_current(generation) || !_eligible || AdService().adsSuppressed) {
      return;
    }
    _retry?.cancel();
    _failures = (_failures + 1).clamp(1, 5);
    _retry = Timer(Duration(seconds: (15 * (1 << _failures)).clamp(30, 300)),
        () => unawaited(_load(generation)));
  }

  Future<void> _load(int generation) async {
    if (!_current(generation) || !_eligible || _loaded || _loading) return;
    final ads = AdService();
    final unitId = ads.nativeAdUnitId;
    if (ads.adsSuppressed || unitId == null) return;
    _retry?.cancel();
    _loading = true;
    try {
      await ads.init();
      if (!_current(generation)) return;
      if (!ads.canRequestAds || !_eligible) {
        _loading = false;
        _scheduleRetry(generation);
        return;
      }
      final native = NativeAd(
        adUnitId: unitId,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
          mainBackgroundColor: CinemaPalette.surface,
          cornerRadius: 14,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: CinemaPalette.background,
            backgroundColor: CinemaPalette.gold,
            style: NativeTemplateFontStyle.bold,
            size: 15,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: CinemaPalette.ivory,
            style: NativeTemplateFontStyle.bold,
            size: 16,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: CinemaPalette.muted,
            size: 14,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: CinemaPalette.muted,
            size: 12,
          ),
        ),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!_current(generation)) return;
            _loading = false;
            if (!ads.canRequestAds) {
              _ad = null;
              ad.dispose();
              return;
            }
            _failures = 0;
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!_current(generation)) return;
            _ad = null;
            _loading = false;
            debugPrint(
                'Ads native failed placement=my-list code=${error.code}');
            _scheduleRetry(generation);
          },
        ),
      );
      _ad = native;
      await native.load();
    } catch (error) {
      if (!_current(generation)) return;
      _ad?.dispose();
      _ad = null;
      _loading = false;
      debugPrint('Ads native unavailable: ${error.runtimeType}');
      _scheduleRetry(generation);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported || AdService().adsSuppressed) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(builder: (context, constraints) {
      // Do not scale or clip the SDK's native template on narrow screens.
      final wideEnough = constraints.maxWidth >= 320;
      if (wideEnough != _wideEnough) {
        _wideEnough = wideEnough;
        if (wideEnough) _queueLoad();
      }
      if (!wideEnough || !_loaded || _ad == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Advertisement',
                    style: TextStyle(color: CinemaPalette.muted, fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: AdWidget(ad: _ad!),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _generation++;
    _retry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AdService().privacyChanges.removeListener(_privacyChanged);
    _ad?.dispose();
    super.dispose();
  }
}
