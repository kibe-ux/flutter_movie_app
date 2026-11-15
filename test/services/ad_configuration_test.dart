import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviehub_app/config/ad_configuration.dart';

void main() {
  test('debug test device registration validates and deduplicates device IDs',
      () {
    final config = AdConfiguration(
      platform: TargetPlatform.android,
      isRelease: false,
      testDeviceIdsValue:
          ' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,invalid,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB ',
    );
    expect(config.testDeviceIds, [
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
    ]);
  });

  test('release ignores developer test device registration', () {
    final config = AdConfiguration(
      platform: TargetPlatform.android,
      isRelease: true,
      testDeviceIdsValue: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    );
    expect(config.testDeviceIds, isEmpty);
  });

  const live = {
    'ADMOB_USE_TEST_ADS': 'false',
    'ADMOB_BANNER_ID': 'ca-app-pub-1234567890123456/1111111111',
    'ADMOB_INTERSTITIAL_ID': 'ca-app-pub-1234567890123456/2222222222',
    'ADMOB_REWARDED_ID': 'ca-app-pub-1234567890123456/3333333333',
  };
  test('native demo units match the platform and cannot go live in debug', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final config = AdConfiguration(
        platform: platform,
        isRelease: false,
        environment: {
          ...live,
          'ADMOB_NATIVE_ID': 'ca-app-pub-1234567890123456/4444444444',
        },
      );
      expect(config.nativeId,
          'ca-app-pub-3940256099942544/${platform == TargetPlatform.iOS ? '3986624511' : '2247696110'}');
    }
  });

  test(
      'unconfigured native placement does not switch existing live ads to test',
      () {
    for (final value in [
      '',
      'invalid',
      'ca-app-pub-3940256099942544/2247696110'
    ]) {
      final config = AdConfiguration(
        platform: TargetPlatform.android,
        isRelease: true,
        environment: {...live, 'ADMOB_NATIVE_ID': value},
      );
      expect(config.useTestAds, isFalse);
      expect(config.nativeId, isNull);
      expect(config.bannerId, live['ADMOB_BANNER_ID']);
    }
    final config = AdConfiguration(
      platform: TargetPlatform.android,
      isRelease: true,
      environment: {
        ...live,
        'ADMOB_NATIVE_ID': 'ca-app-pub-1234567890123456/4444444444',
      },
    );
    expect(config.nativeId, 'ca-app-pub-1234567890123456/4444444444');
  });
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
    expect(config.bannerId, 'ca-app-pub-3940256099942544/2934735716');
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
      expect(config.bannerId, 'ca-app-pub-3940256099942544/6300978111');
    }
  });
}
