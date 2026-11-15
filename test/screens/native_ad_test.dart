import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart' as plugin;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/services/ad_free_access.dart';
import 'package:moviehub_app/services/ad_service.dart';
import 'package:moviehub_app/widgets/movie_hub_native_ad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdFreeAccess.instance.clear();
    requests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin.instanceManager.channel, (call) async {
      requests.add(call);
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus({});
      }
      return null;
    });
    AdService().beginPrivacyUpdate();
  });

  tearDown(() {
    AdFreeAccess.instance.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin.instanceManager.channel, null);
  });

  Widget host({double width = 400, bool active = true}) => MaterialApp(
        home: Scaffold(
          body: TickerMode(
            enabled: active,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: const MovieHubNativeAd()),
            ),
          ),
        ),
      );

  testWidgets(
      'no-fill stays collapsed, backs off and stops retrying on removal',
      (tester) async {
    unawaited(AdService().finishPrivacyUpdate());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    var loads = requests.where((r) => r.method == 'loadNativeAd').toList();
    expect(loads, hasLength(1));
    expect(tester.getSize(find.byType(MovieHubNativeAd)).height, 0);
    final id = (loads.single.arguments as Map)['adId'] as int;
    final ad = plugin.instanceManager.adFor(id) as NativeAd;
    expect(ad.adUnitId, 'ca-app-pub-3940256099942544/2247696110');
    ad.listener.onAdFailedToLoad!(ad, LoadAdError(3, 'test', 'No fill', null));
    await tester.pump(const Duration(seconds: 29));
    expect(requests.where((r) => r.method == 'loadNativeAd'), hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    loads = requests.where((r) => r.method == 'loadNativeAd').toList();
    expect(loads, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 5));
    expect(requests.where((r) => r.method == 'loadNativeAd'), hasLength(2));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('ad-free entitlement discards a pending native load',
      (tester) async {
    unawaited(AdService().finishPrivacyUpdate());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final load = requests.singleWhere((r) => r.method == 'loadNativeAd');
    final id = (load.arguments as Map)['adId'] as int;
    final ad = plugin.instanceManager.adFor(id) as NativeAd;
    final now = DateTime.now();
    AdFreeAccess.instance.update(
      uid: 'test-user',
      until: now.add(const Duration(hours: 1)),
      serverTime: now,
    );
    await tester.pump();
    ad.listener.onAdLoaded!(ad);
    await tester.pump();
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.getSize(find.byType(MovieHubNativeAd)).height, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    AdService().beginPrivacyUpdate();
    AdFreeAccess.instance.clear();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('narrow layouts and inactive tabs do not request native ads',
      (tester) async {
    unawaited(AdService().finishPrivacyUpdate());
    await tester.pumpWidget(host(width: 280));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'loadNativeAd'), isEmpty);
    await tester.pumpWidget(host(active: false));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'loadNativeAd'), isEmpty);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'loadNativeAd'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
