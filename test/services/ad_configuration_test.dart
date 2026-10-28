import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/config/ad_configuration.dart';

void main() {
  const live = {
    'ADMOB_USE_TEST_ADS': 'false',
    'ADMOB_BANNER_ID': 'ca-app-pub-1234567890123456/1111111111',
    'ADMOB_INTERSTITIAL_ID': 'ca-app-pub-1234567890123456/2222222222',
    'ADMOB_REWARDED_ID': 'ca-app-pub-1234567890123456/3333333333',
  };
  test('empty configuration uses Google test ads even in release', () {
    final config =
        AdConfiguration(platform: TargetPlatform.android, isRelease: true);
    expect(config.useTestAds, isTrue);
    expect(config.rewardedId, 'ca-app-pub-3940256099942544/5224354917');
  });
  test('release can select all publisher ad units by configuration alone', () {
    final config = AdConfiguration(
        platform: TargetPlatform.android, isRelease: true, environment: live);
    expect(config.useTestAds, isFalse);
    expect(config.bannerId, live['ADMOB_BANNER_ID']);
    expect(config.interstitialId, live['ADMOB_INTERSTITIAL_ID']);
    expect(config.rewardedId, live['ADMOB_REWARDED_ID']);
  });
  test('explicit test mode takes priority over publisher units', () {
    final config = AdConfiguration(
        platform: TargetPlatform.iOS,
        isRelease: true,
        environment: {...live, 'ADMOB_USE_TEST_ADS': 'true'});
    expect(config.useTestAds, isTrue);
    expect(config.bannerId, 'ca-app-pub-3940256099942544/2435281174');
    expect(config.rewardedId, 'ca-app-pub-3940256099942544/1712485313');
  });
  test('debug builds always use test inventory', () {
    final config = AdConfiguration(
        platform: TargetPlatform.android, isRelease: false, environment: live);
    expect(config.useTestAds, isTrue);
  });
  test(
      'incomplete, malformed or sample production values fall back to test mode',
      () {
    for (final value in [
      '',
      'invalid',
      'ca-app-pub-3940256099942544/5224354917'
    ]) {
      final config = AdConfiguration(
          platform: TargetPlatform.android,
          isRelease: true,
          environment: {...live, 'ADMOB_REWARDED_ID': value});
      expect(config.useTestAds, isTrue);
      expect(config.bannerId, 'ca-app-pub-3940256099942544/9214589741');
    }
  });
}
