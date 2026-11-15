import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test ads by default; live ads require an explicit release configuration.
class AdConfiguration {
  AdConfiguration({
    required this.platform,
    this.isRelease = kReleaseMode,
    this.environment = const {},
    this.testDeviceIdsValue =
        const String.fromEnvironment('ADMOB_TEST_DEVICE_IDS'),
  });

  factory AdConfiguration.fromEnvironment() => AdConfiguration(
        platform: defaultTargetPlatform,
        environment: dotenv.isInitialized ? dotenv.env : const {},
      );

  final TargetPlatform platform;
  final bool isRelease;
  final Map<String, String> environment;
  final String testDeviceIdsValue;

  List<String> get testDeviceIds => isRelease
      ? const []
      : testDeviceIdsValue
          .split(',')
          .map((id) => id.trim().toUpperCase())
          .where((id) => RegExp(r'^[A-F0-9]{32}$').hasMatch(id))
          .toSet()
          .toList();
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
  // A missing native unit must not change the mode of existing ad formats.
  // In production, keep this optional placement hidden until configured.
  String? get nativeId {
    if (useTestAds) {
      return '$_demoPublisher${_ios ? '3986624511' : '2247696110'}';
    }
    final value = _value('ADMOB_NATIVE_ID');
    return _unitPattern.hasMatch(value) && !value.startsWith(_demoPublisher)
        ? value
        : null;
  }

  String get bannerId => useTestAds
      ? '$_demoPublisher${_ios ? '2934735716' : '6300978111'}'
      : _value('ADMOB_BANNER_ID');
  String get interstitialId => useTestAds
      ? '$_demoPublisher${_ios ? '4411468910' : '1033173712'}'
      : _value('ADMOB_INTERSTITIAL_ID');
  String get rewardedId => useTestAds
      ? '$_demoPublisher${_ios ? '1712485313' : '5224354917'}'
      : _value('ADMOB_REWARDED_ID');
}
