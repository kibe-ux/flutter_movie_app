import 'dart:async';
import 'package:flutter/foundation.dart';

class AdFreeAccess extends ChangeNotifier {
  static final instance = AdFreeAccess();
  String? _uid;
  DateTime? _until;
  Stopwatch? _elapsed;
  Duration _remaining = Duration.zero;
  Timer? _expiry;

  String? get uid => _uid;
  DateTime? get until => _until;
  bool get active =>
      _uid != null && _elapsed != null && _elapsed!.elapsed < _remaining;

  void clear() {
    _uid = null;
    _until = null;
    _elapsed = null;
    _expiry?.cancel();
    notifyListeners();
  }

  void update(
      {required String uid,
      required DateTime until,
      required DateTime serverTime}) {
    _expiry?.cancel();
    _uid = uid;
    _until = until;
    _remaining = until.difference(serverTime);
    _elapsed = Stopwatch()..start();
    if (_remaining > Duration.zero) {
      _expiry = Timer(_remaining, notifyListeners);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }
}
