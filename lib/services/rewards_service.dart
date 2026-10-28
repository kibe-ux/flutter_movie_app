import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'ad_free_access.dart';
import 'ad_service.dart';
import 'rewarded_ad_gateway.dart';

class RewardOffer {
  const RewardOffer(this.id, this.coins, this.hours);
  final String id;
  final int coins;
  final int hours;
}

enum RewardsActivity { idle, loadingAd, showingAd, confirmingReward, redeeming }

class RewardsService extends ChangeNotifier with WidgetsBindingObserver {
  RewardsService(
      {http.Client? client,
      RewardedGateway? gateway,
      Future<String?> Function()? tokenProvider,
      String? baseUrl,
      AdFreeAccess? access,
      String? rewardedUnitId,
      Future<void> Function(Duration)? delay})
      : _client = client ?? http.Client(),
        _gateway = gateway ?? GoogleRewardedGateway(),
        _tokenProvider = tokenProvider ?? _token,
        _baseUrl = baseUrl,
        _access = access ?? AdFreeAccess.instance,
        _unitOverride = rewardedUnitId,
        _delay = delay ?? Future<void>.delayed {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  final http.Client _client;
  final RewardedGateway _gateway;
  final Future<String?> Function() _tokenProvider;
  final String? _baseUrl;
  final String? _unitOverride;
  final AdFreeAccess _access;
  final Future<void> Function(Duration) _delay;
  String? _uid;
  bool _disposed = false;
  bool busy = false;
  RewardsActivity activity = RewardsActivity.idle;
  String get activityLabel => switch (activity) {
        RewardsActivity.idle => '',
        RewardsActivity.loadingAd => 'Loading your ad...',
        RewardsActivity.showingAd => 'Ad in progress',
        RewardsActivity.confirmingReward => 'Confirming your reward...',
        RewardsActivity.redeeming => 'Activating your pass...',
      };
  bool enabled = false;
  bool pending = false;
  bool loaded = false;
  int coins = 0;
  int coinsPerAd = 10;
  String? message;
  List<RewardOffer> offers = const [];
  Future<void>? _refreshing;
  String? _redemptionId;
  String? _redemptionOffer;
  static Future<String?> _token() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();
  String get unitId => _unitOverride ?? AdService().rewardedAdUnitId;
  bool get testAds => AdService().usesTestAds;
  bool get adFree => _access.active;
  DateTime? get adFreeUntil => _access.until;
  bool get supported =>
      !kIsWeb &&
      [TargetPlatform.android, TargetPlatform.iOS]
          .contains(defaultTargetPlatform);

  void setUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    coins = 0;
    enabled = false;
    loaded = false;
    pending = false;
    offers = const [];
    message = null;
    _refreshing = null;
    _redemptionId = null;
    _redemptionOffer = null;
    scheduleMicrotask(() {
      if (_disposed || _uid != uid) return;
      _access.clear();
      if (uid != null) unawaited(refresh());
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>> _request(String path,
      {Map<String, dynamic>? body, required String uid}) async {
    final token = await _tokenProvider();
    if (_uid != uid || _disposed) {
      throw StateError('Your account has changed. Please try again.');
    }
    if (token == null || token.isEmpty) {
      throw StateError('Sign in to access Cinema Rewards.');
    }
    final base = (_baseUrl ??
            (dotenv.isInitialized
                ? dotenv.env['MOVIE_DOWNLOAD_API_BASE_URL']
                : null) ??
            '')
        .replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw StateError(
          'Cinema Rewards is being prepared. Please check back later.');
    }
    final uri = Uri.parse('$base/api/rewards/$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final response = await (body == null
            ? _client.get(uri, headers: headers)
            : _client.post(uri, headers: headers, body: jsonEncode(body)))
        .timeout(const Duration(seconds: 20));
    if (_uid != uid || _disposed) {
      throw StateError('Your account has changed. Please try again.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('Please sign in again to access Cinema Rewards.');
    }
    if (response.statusCode == 404) {
      throw StateError(
          'Cinema Rewards is being prepared. Please check back later.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(data['error'] as String? ??
          'Cinema Rewards is temporarily unavailable.');
    }
    return data;
  }

  void _wallet(Map<String, dynamic> data, String uid) {
    coins = (data['coins'] as num).toInt();
    coinsPerAd = (data['coinsPerAd'] as num).toInt();
    enabled = data['enabled'] == true;
    pending = data['pendingReward'] == true;
    offers = (data['offers'] as List)
        .map((e) => RewardOffer(e['id'] as String, (e['coins'] as num).toInt(),
            (e['hours'] as num).toInt()))
        .toList();
    _access.update(
        uid: uid,
        until: DateTime.fromMillisecondsSinceEpoch(
            (data['adFreeUntil'] as num).toInt()),
        serverTime: DateTime.fromMillisecondsSinceEpoch(
            (data['serverTime'] as num).toInt()));
    loaded = true;
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    final uid = _uid;
    if (uid == null || _disposed) return;
    try {
      final data = await _request('wallet', uid: uid);
      _wallet(data, uid);
      message = null;
    } catch (error) {
      if (_uid == uid) message = _friendly(error);
    }
    _notify();
  }

  /// Lets members verify the native test ad without a live rewards backend.
  /// Demo completions never call the wallet/session/credit APIs.
  Future<void> watchTestAd({required bool Function() isActive}) async {
    final uid = _uid;
    if (uid == null || busy || adFree || !testAds) return;
    busy = true;
    activity = RewardsActivity.loadingAd;
    message = null;
    _notify();
    RewardedVideo? ad;
    try {
      ad = await _gateway.load(unitId);
      if (_disposed || _uid != uid || !isActive()) return;
      activity = RewardsActivity.showingAd;
      _notify();
      final completed = await ad.show(uid: uid, sessionId: 'test-preview');
      if (!_disposed && _uid == uid) {
        message = completed
            ? 'Test ad completed. Demo ads do not add spendable coins.'
            : 'Test ad closed. Your coin balance is unchanged.';
      }
    } catch (error) {
      if (_uid == uid) message = _friendly(error);
    } finally {
      ad?.dispose();
      busy = false;
      activity = RewardsActivity.idle;
      _notify();
    }
  }

  Future<void> watch({required bool Function() isActive}) async {
    final uid = _uid;
    if (uid == null || busy || !enabled || adFree || pending) return;
    busy = true;
    activity = RewardsActivity.loadingAd;
    message = null;
    _notify();
    RewardedVideo? ad;
    Map<String, dynamic>? session;
    bool earned = false;
    try {
      ad = await _gateway.load(unitId);
      if (!isActive() || _uid != uid || _disposed) return;
      session = await _request('session', uid: uid, body: {'unitId': unitId});
      if (!isActive() || _uid != uid || _disposed) return;
      activity = RewardsActivity.showingAd;
      _notify();
      earned = await ad.show(uid: uid, sessionId: session['id'] as String);
      if (_uid != uid || _disposed) return;
      if (earned) {
        activity = RewardsActivity.confirmingReward;
        pending = true;
        message =
            'Your reward is being confirmed. Refresh shortly to check your coins.';
        _notify();
        // The SDK callback never grants coins; only a signed server callback can.
        for (var attempt = 0; attempt < 5; attempt++) {
          await _delay(const Duration(seconds: 2));
          if (_uid != uid || _disposed) return;
          final data = await _request('wallet', uid: uid);
          _wallet(data, uid);
          if (!pending) {
            message = 'Your reward has been added to your balance.';
            break;
          }
        }
      } else {
        message = 'Ad closed. You can keep browsing or try again later.';
      }
    } catch (error) {
      if (_uid == uid && !_disposed) message = _friendly(error);
    } finally {
      ad?.dispose();
      if (session != null && !earned && _uid == uid && !_disposed) {
        try {
          await _request('cancel',
              uid: uid, body: {'sessionId': session['id']});
        } catch (_) {
          /* The server session expires if cancellation cannot connect. */
        }
      }
      busy = false;
      activity = RewardsActivity.idle;
      _notify();
    }
  }

  Future<void> redeem(RewardOffer offer) async {
    final uid = _uid;
    if (uid == null || busy || coins < offer.coins) return;
    busy = true;
    activity = RewardsActivity.redeeming;
    message = null;
    _notify();
    if (_redemptionOffer != offer.id) {
      _redemptionOffer = offer.id;
      final random = Random.secure();
      _redemptionId = List.generate(
              24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
    }
    try {
      final data = await _request('redeem',
          uid: uid, body: {'offerId': offer.id, 'requestId': _redemptionId});
      _wallet(data, uid);
      _redemptionId = null;
      _redemptionOffer = null;
      message = 'Your ad-free pass is active. Enjoy your movies.';
    } catch (error) {
      if (_uid == uid) message = _friendly(error);
    } finally {
      busy = false;
      activity = RewardsActivity.idle;
      _notify();
    }
  }

  String _friendly(Object error) => error is StateError
      ? error.message.toString()
      : 'Cinema Rewards could not connect. Please try again.';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
