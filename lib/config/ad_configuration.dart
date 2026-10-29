import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdConfiguration {
  AdConfiguration({
    required this.platform,
    this.isRelease = kReleaseMode,
    this.environment = const {},
  });

  factory AdConfiguration.fromEnvironment() => AdConfiguration(
        platform: defaultTargetPlatform,
        environment: dotenv.isInitialized ? dotenv.env : const {},
      );

  final TargetPlatform platform;
  final bool isRelease;
  final Map<String, String> environment;
  static const _demoPublisher = 'ca-app-pub-3940256099942544/';
  static final _unitPattern = RegExp(r'^ca-app-pub-\d{16}/\d{10}$');

  String _value(String key) => environment[key]?.trim() ?? '';
  bool get useTestAds =>
      !isRelease ||
      _value('ADMOB_USE_TEST_ADS') != 'false' ||
      ['ADMOB_BANNER_ID', 'ADMOB_INTERSTITIAL_ID', 'ADMOB_REWARDED_ID'].any(
          (key) =>
              !_unitPattern.hasMatch(_value(key)) ||
              _value(key).startsWith(_demoPublisher));

  bool get _ios => platform == TargetPlatform.iOS;
  String get bannerId => useTestAds
      ? '$_demoPublisher${_ios ? '2435281174' : '9214589741'}'
      : _value('ADMOB_BANNER_ID');
  String get interstitialId => useTestAds
      ? '$_demoPublisher${_ios ? '4411468910' : '1033173712'}'
      : _value('ADMOB_INTERSTITIAL_ID');
  String get rewardedId => useTestAds
      ? '$_demoPublisher${_ios ? '1712485313' : '5224354917'}'
      : _value('ADMOB_REWARDED_ID');
}
