import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

class MovieHubBannerAd extends StatefulWidget {
  const MovieHubBannerAd({super.key, required this.placement});

  final String placement;

  @override
  State<MovieHubBannerAd> createState() => _MovieHubBannerAdState();
}

class _MovieHubBannerAdState extends State<MovieHubBannerAd>
    with WidgetsBindingObserver {
  BannerAd? _banner;
  AdSize? _slotSize;
  Timer? _retry;
  int _width = 0;
  int _generation = 0;
  int _failures = 0;
  bool _loaded = false;
  bool _loading = false;
  bool _foreground = true;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdService().privacyChanges.addListener(_privacyChanged);
  }

  void _privacyChanged() {
    if (!mounted) return;
    _retry?.cancel();
    final generation = ++_generation;
    _loading = false;
    final oldBanner = _banner;
    setState(() {
      _loaded = false;
      _banner = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldBanner?.dispose();
      if (_current(generation) && AdService().canRequestAds) {
        unawaited(_load(generation));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _retry?.cancel();
    } else if (!_loaded && !_loading && _width > 0) {
      unawaited(_load(_generation));
    }
  }

  bool _current(int generation) => mounted && generation == _generation;

  void _scheduleRetry(int generation) {
    if (!_current(generation) || !_foreground || AdService().adsSuppressed) {
      return;
    }
    _retry?.cancel();
    _failures = (_failures + 1).clamp(1, 5);
    final seconds = (15 * (1 << _failures)).clamp(30, 300);
    debugPrint(
        'Ads banner retry placement=${widget.placement} delay=${seconds}s');
    _retry = Timer(Duration(seconds: seconds), () {
      if (_current(generation)) unawaited(_load(generation));
    });
  }

  Future<void> _load(int generation) async {
    if (!_current(generation) || !_foreground) return;
    _retry?.cancel();
    _loading = true;
    final oldBanner = _banner;
    setState(() {
      _banner = null;
      _loaded = false;
    });
    if (oldBanner != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldBanner.dispose());
    }
    try {
      final ads = AdService();
      await ads.init();
      if (!_current(generation)) return;
      if (!ads.canRequestAds) {
        _loading = false;
        _scheduleRetry(generation);
        return;
      }
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              _width);
      if (!_current(generation)) return;
      if (size == null) throw StateError('Adaptive banner size unavailable');
      setState(() => _slotSize = size);
      final banner = BannerAd(
        adUnitId: ads.bannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!_current(generation)) {
              ad.dispose();
              return;
            }
            _loading = false;
            _failures = 0;
            setState(() => _loaded = true);
            debugPrint('Ads banner loaded placement=${widget.placement} '
                'mode=${ads.usesTestAds ? 'test' : 'production'}');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!_current(generation)) return;
            _loading = false;
            setState(() {
              _banner = null;
              _loaded = false;
            });
            debugPrint('Ads banner failed placement=${widget.placement} '
                'code=${error.code} domain=${error.domain} message=${error.message}');
            _scheduleRetry(generation);
          },
        ),
      );
      _banner = banner;
      await banner.load();
    } catch (error) {
      if (!_current(generation)) return;
      _loading = false;
      final failedBanner = _banner;
      setState(() {
        _banner = null;
        _loaded = false;
      });
      if (failedBanner != null) unawaited(failedBanner.dispose());
      debugPrint('Ads banner unavailable placement=${widget.placement} '
          'error=${error.runtimeType}');
      _scheduleRetry(generation);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported || AdService().adsSuppressed) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth.truncate()
          : MediaQuery.sizeOf(context).width.truncate();
      if (width > 0 && width != _width) {
        _width = width;
        final generation = ++_generation;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current(generation)) unawaited(_load(generation));
        });
      }
      final banner = _banner;
      final size = _slotSize;
      if (size == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SizedBox(
          width: double.infinity,
          height: size.height.toDouble(),
          child: Center(
            child: !_loaded || banner == null
                ? const SizedBox.shrink()
                : SizedBox(
                    width: banner.size.width.toDouble(),
                    height: banner.size.height.toDouble(),
                    child: AdWidget(ad: banner),
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
    _banner?.dispose();
    super.dispose();
  }
}
