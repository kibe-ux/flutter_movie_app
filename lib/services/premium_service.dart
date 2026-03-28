import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumService extends ChangeNotifier {
  static const String _premiumKey = 'is_premium_user';
  bool _isPremium = false;

  bool get isPremium => _isPremium;

  PremiumService() {
    _loadPremiumState();
  }

  Future<void> _loadPremiumState() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumKey) ?? false;
    notifyListeners();
  }

  Future<void> upgradeToPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    _isPremium = true;
    notifyListeners();
  }

  Future<void> revokePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, false);
    _isPremium = false;
    notifyListeners();
  }
}
