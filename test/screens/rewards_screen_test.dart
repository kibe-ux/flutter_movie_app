import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:moviehub_app/screens/rewards_screen.dart';
import 'package:moviehub_app/services/auth_service.dart';
import 'package:moviehub_app/services/rewards_service.dart';
import 'package:moviehub_app/services/rewarded_ad_gateway.dart';
import 'package:moviehub_app/services/ad_free_access.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'viewer';
  @override
  bool get isAnonymous => false;
}

class _Auth extends ChangeNotifier implements AuthService {
  bool signedIn = true;
  @override
  User? get currentUser => signedIn ? _User() : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway extends Fake implements RewardedGateway {
  int loads = 0;
  @override
  Future<RewardedVideo> load(String unitId) async {
    loads++;
    throw StateError('No ad');
  }
}

void main() {
  Future<({RewardsService rewards, _Gateway gateway, List<String> calls})> show(
      WidgetTester tester,
      {bool guest = false,
      bool unavailable = false,
      bool Function()? isUnavailable,
      double width = 430,
      double textScale = 1,
      int coins = 30}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _Auth()..signedIn = !guest;
    final gateway = _Gateway();
    final calls = <String>[];
    final access = AdFreeAccess();
    var walletCoins = coins;
    var adFreeUntil = 0;
    final rewards = RewardsService(
        access: access,
        gateway: gateway,
        tokenProvider: () async => 'token',
        baseUrl: 'https://backend.example',
        rewardedUnitId: 'test-unit',
        client: MockClient((request) async {
          calls.add(request.url.path);
          if (isUnavailable?.call() ?? unavailable) {
            return http.Response(
                '{"error":"Rewards temporarily unavailable"}', 503);
          }
          if (request.url.path.endsWith('/redeem')) {
            walletCoins -= 30;
            adFreeUntil = 3601000;
          }
          return http.Response(
              jsonEncode({
                'coins': walletCoins,
                'adFreeUntil': adFreeUntil,
                'serverTime': 1000,
                'enabled': true,
                'pendingReward': false,
                'coinsPerAd': 10,
                'offers': [
                  {'id': 'hour', 'coins': 30, 'hours': 1}
                ]
              }),
              200);
        }));
    rewards.setUser(guest ? null : 'viewer');
    addTearDown(rewards.dispose);
    addTearDown(auth.dispose);
    addTearDown(access.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<RewardsService>.value(value: rewards),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const RewardsScreen(),
        )));
    await tester.pumpAndSettle();
    return (rewards: rewards, gateway: gateway, calls: calls);
  }

  testWidgets('guests see account access without wallet or ad requests',
      (tester) async {
    final state = await show(tester, guest: true);
    expect(find.text('Sign in to Cinema Rewards'), findsOneWidget);
    expect(find.text('Earn at your own pace'), findsNothing);
    expect(state.calls, isEmpty);
    expect(state.gateway.loads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('unavailable wallets still show disabled ad-free pass previews',
      (tester) async {
    final state = await show(tester, unavailable: true);
    expect(find.text('YOUR COIN BALANCE'), findsOneWidget);
    expect(find.text('Load my balance'), findsOneWidget);
    expect(find.textContaining('Balance unavailable.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 hour ad-free'), 200);
    await tester.pumpAndSettle();
    final preview = find.text('Connect to redeem').first;
    await tester.ensureVisible(preview);
    final button = tester.widget<OutlinedButton>(find
        .ancestor(of: preview, matching: find.byType(OutlinedButton))
        .first);
    expect(button.onPressed, isNull);
    expect(state.calls.where((path) => path.endsWith('/redeem')), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'small screens and large text retain readable balance and optional controls',
      (tester) async {
    final state = await show(tester, width: 320, textScale: 2, coins: 10);
    expect(find.text('10 / 30 coins toward a 1-hour pass'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('20 more coins needed'), 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Watch test ad'), -300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(state.gateway.loads, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('watching is opt-in and declining never loads an ad',
      (tester) async {
    final state = await show(tester);
    expect(state.gateway.loads, 0);
    await tester.scrollUntilVisible(find.text('Watch test ad'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch test ad'));
    await tester.pumpAndSettle();
    expect(find.text('Preview a test ad?'), findsOneWidget);
    expect(find.textContaining('It does not add spendable coins.'),
        findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(state.gateway.loads, 0);
    expect(state.rewards.coins, 30);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets(
      'redemption discloses cost and duration; cancellation never spends coins',
      (tester) async {
    final state = await show(tester);
    await tester.scrollUntilVisible(find.text('Redeem 30 coins'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem 30 coins'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use 30 coins for 1 hour'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(state.rewards.coins, 30);
    expect(state.calls.where((path) => path.endsWith('/redeem')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('confirmed redemption updates balance and activates the pass',
      (tester) async {
    final state = await show(tester);
    await tester.scrollUntilVisible(find.text('Redeem 30 coins'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem 30 coins'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem coins'));
    await tester.pumpAndSettle();
    expect(state.rewards.coins, 0);
    expect(state.rewards.adFree, isTrue);
    expect(state.calls.where((path) => path.endsWith('/redeem')).length, 1);
    await tester.scrollUntilVisible(find.text('AD-FREE PASS ACTIVE'), -300);
    await tester.pumpAndSettle();
    expect(find.text('AD-FREE PASS ACTIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.rewards.setUser(null);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wallet retry recovers the balance without leaving rewards',
      (tester) async {
    var offline = true;
    final state = await show(tester, isUnavailable: () => offline);
    await tester.scrollUntilVisible(find.text('Try again'), 200);
    await tester.pumpAndSettle();
    offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(state.rewards.loaded, isTrue);
    expect(state.rewards.refreshFailed, isFalse);
    expect(state.rewards.coins, 30);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
