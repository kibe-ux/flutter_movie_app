import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart' as plugin;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moviehub_app/widgets/movie_hub_banner_ad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin.instanceManager.channel, (call) async {
      requests.add(call);
      switch (call.method) {
        case 'MobileAds#initialize':
          return InitializationStatus({});
        case 'AdSize#getAnchoredAdaptiveBannerAdSize':
          return 50;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(plugin.instanceManager.channel, null);
  });

  testWidgets(
      'banner waits for load, backs off failures and cancels retries on removal',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(bottomNavigationBar: MovieHubBannerAd(placement: 'test')),
    ));
    await tester.pumpAndSettle();
    var loads = requests.where((r) => r.method == 'loadBannerAd').toList();
    expect(loads, hasLength(1));
    expect(find.byType(AdWidget), findsNothing);
    final id = (loads.single.arguments as Map)['adId'] as int;
    final ad = plugin.instanceManager.adFor(id) as BannerAd;
    ad.listener.onAdFailedToLoad!(ad, LoadAdError(2, 'test', 'Offline', null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 29));
    expect(requests.where((r) => r.method == 'loadBannerAd'), hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    loads = requests.where((r) => r.method == 'loadBannerAd').toList();
    expect(loads, hasLength(2));
    final nextId = (loads.last.arguments as Map)['adId'] as int;
    final next = plugin.instanceManager.adFor(nextId) as BannerAd;
    next.listener.onAdFailedToLoad!(
        next, LoadAdError(3, 'test', 'No fill', null));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 5));
    expect(requests.where((r) => r.method == 'loadBannerAd'), hasLength(2));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
