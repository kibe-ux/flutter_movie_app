import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviehub_app/services/ad_free_access.dart';
import 'package:moviehub_app/services/rewarded_ad_gateway.dart';
import 'package:moviehub_app/services/rewards_service.dart';

class _Video implements RewardedVideo {
  Completer<bool>? completion;
  bool earned = false;
  bool disposed = false;
  int shows = 0;
  @override
  Future<bool> show({required String uid, required String sessionId}) async {
    expect(uid, 'viewer');
    expect(sessionId, anyOf('session', 'test-preview'));
    shows++;
    return completion?.future ?? earned;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class _Gateway implements RewardedGateway {
  Completer<RewardedVideo>? pending;
  final video = _Video();
  int loads = 0;
  @override
  Future<RewardedVideo> load(String unitId) async {
    loads++;
    return pending?.future ?? video;
  }
}

Map<String, dynamic> wallet(
        {int coins = 0, bool pending = false, int until = 0}) =>
    {
      'coins': coins,
      'enabled': true,
      'pendingReward': pending,
      'adFreeUntil': until,
      'serverTime': 1000000,
      'coinsPerAd': 10,
      'offers': [
        {'id': 'hour', 'coins': 30, 'hours': 1}
      ],
    };
http.Response json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdFreeAccess access;
  late _Gateway gateway;
  late RewardsService service;
  final calls = <http.Request>[];
  late FutureOr<http.Response> Function(http.Request) handle;
  setUp(() {
    access = AdFreeAccess();
    gateway = _Gateway();
    calls.clear();
    handle = (_) => json(wallet());
    service = RewardsService(
        access: access,
        gateway: gateway,
        baseUrl: 'https://backend.example',
        tokenProvider: () async => 'test-token',
        rewardedUnitId: 'test-unit',
        delay: (_) async {},
        client: MockClient((request) async {
          calls.add(request);
          return handle(request);
        }));
  });
  tearDown(() {
    service.dispose();
    access.dispose();
  });
  Future<void> signIn() async {
    service.setUser('viewer');
    await Future<void>.delayed(Duration.zero);
    await service.refresh();
  }

  test('guests cannot load rewarded ads or redeem coins', () async {
    await service.watch(isActive: () => true);
    await service.watchTestAd(isActive: () => true);
    await service.redeem(const RewardOffer('hour', 30, 1));
    expect(calls, isEmpty);
    expect(gateway.loads, 0);
  });
  test(
      'test rewarded preview works without enabled rewards and never grants coins',
      () async {
    await signIn();
    service.enabled = false;
    gateway.video.earned = true;
    await service.watchTestAd(isActive: () => true);
    expect(gateway.video.shows, 1);
    expect(service.coins, 0);
    expect(gateway.video.disposed, isTrue);
    expect(calls.where((request) => request.method == 'POST'), isEmpty);
    expect(service.message, contains('Demo ads do not add spendable coins'));
  });

  test(
      'ad progress follows load, presentation and dismissal without duplicate requests',
      () async {
    await signIn();
    gateway.pending = Completer<RewardedVideo>();
    gateway.video.completion = Completer<bool>();
    final watch = service.watchTestAd(isActive: () => true);
    expect(service.activity, RewardsActivity.loadingAd);
    await service.watchTestAd(isActive: () => true);
    expect(gateway.loads, 1);
    gateway.pending!.complete(gateway.video);
    await Future<void>.delayed(Duration.zero);
    expect(service.activity, RewardsActivity.showingAd);
    gateway.video.completion!.complete(false);
    await watch;
    expect(service.activity, RewardsActivity.idle);
    expect(service.busy, isFalse);
    expect(service.coins, 0);
  });

  test('account switch discards a stale wallet response', () async {
    final pending = Completer<http.Response>();
    handle = (_) => pending.future;
    service.setUser('viewer');
    await Future<void>.delayed(Duration.zero);
    service.setUser(null);
    pending.complete(json(wallet(coins: 999, until: 2000000)));
    await Future<void>.delayed(Duration.zero);
    expect(service.coins, 0);
    expect(access.active, isFalse);
  });
  test('leaving before ad loading completes prevents presentation', () async {
    await signIn();
    await service.watch(isActive: () => false);
    expect(gateway.video.shows, 0);
    expect(gateway.video.disposed, isTrue);
    expect(calls.where((c) => c.url.path.endsWith('/session')), isEmpty);
  });
  test('skipped ads cancel their session and never grant coins', () async {
    handle = (request) => json(request.url.path.endsWith('/session')
        ? {'id': 'session'}
        : request.url.path.endsWith('/cancel')
            ? {'cancelled': true}
            : wallet());
    await signIn();
    await service.watch(isActive: () => true);
    expect(gateway.video.shows, 1);
    expect(service.coins, 0);
    expect(calls.last.url.path, '/api/rewards/cancel');
    expect(service.message, contains('Ad closed'));
  });
  test('SDK completion alone cannot mint coins', () async {
    bool started = false;
    handle = (request) {
      if (request.url.path.endsWith('/session')) {
        started = true;
        return json({'id': 'session'});
      }
      return json(wallet(pending: started));
    };
    await signIn();
    gateway.video.earned = true;
    await service.watch(isActive: () => true);
    expect(service.coins, 0);
    expect(service.pending, isTrue);
    expect(access.active, isFalse);
    expect(gateway.video.disposed, isTrue);
  });
  test('confirmed server reward updates the balance', () async {
    bool started = false;
    handle = (request) {
      if (request.url.path.endsWith('/session')) {
        started = true;
        return json({'id': 'session'});
      }
      return json(wallet(coins: started ? 10 : 0));
    };
    await signIn();
    gateway.video.earned = true;
    await service.watch(isActive: () => true);
    expect(service.coins, 10);
    expect(service.pending, isFalse);
  });
  test(
      'uncertain redemption reuses its request ID; only server response activates a pass',
      () async {
    int redemptions = 0;
    handle = (request) {
      if (request.url.path.endsWith('/redeem')) {
        redemptions++;
        return redemptions == 1
            ? json({'error': 'Please retry.'}, 503)
            : json(wallet(until: 4600000));
      }
      return json(wallet(coins: 30));
    };
    await signIn();
    await service.redeem(service.offers.single);
    expect(access.active, isFalse);
    expect(service.coins, 30);
    await service.redeem(service.offers.single);
    final requests =
        calls.where((c) => c.url.path.endsWith('/redeem')).toList();
    expect(jsonDecode(requests[0].body)['requestId'],
        jsonDecode(requests[1].body)['requestId']);
    expect(access.active, isTrue);
    expect(service.coins, 0);
    await service.watch(isActive: () => true);
    expect(gateway.loads, 0);
  });
  test('expired passes and signing out do not suppress ads', () async {
    access.update(
        uid: 'viewer',
        until: DateTime.fromMillisecondsSinceEpoch(999),
        serverTime: DateTime.fromMillisecondsSinceEpoch(1000));
    expect(access.active, isFalse);
    access.update(
        uid: 'viewer',
        until: DateTime.fromMillisecondsSinceEpoch(2000),
        serverTime: DateTime.fromMillisecondsSinceEpoch(1000));
    expect(access.active, isTrue);
    access.clear();
    expect(access.active, isFalse);
  });
}
