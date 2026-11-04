import 'package:shared_preferences/shared_preferences.dart';

/// Manages daily login coin bonuses stored locally per user.
class DailyRewardService {
  static const int dailyBonusCoins = 5;
  static const String _prefix = 'daily_bonus_last_date_';
  static const String _bonusCoinsPrefix = 'local_bonus_coins_';

  /// Checks if the user is eligible for today's daily bonus.
  /// If eligible, awards [dailyBonusCoins] and returns the amount awarded (e.g. 5).
  /// If already claimed today, returns 0.
  static Future<int> claimDailyBonus({String? uid}) async {
    final keyId = uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    
    final today = _dateKey(DateTime.now());
    final lastClaimed = prefs.getString('$_prefix$keyId');

    if (lastClaimed == today) {
      return 0; // Already claimed today
    }

    // Record claim date
    await prefs.setString('$_prefix$keyId', today);
    
    // Increment local bonus coins accumulated
    final currentBonus = prefs.getInt('$_bonusCoinsPrefix$keyId') ?? 0;
    await prefs.setInt('$_bonusCoinsPrefix$keyId', currentBonus + dailyBonusCoins);

    return dailyBonusCoins;
  }

  /// Returns total extra bonus coins saved for this user.
  static Future<int> getBonusCoins({String? uid}) async {
    final keyId = uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_bonusCoinsPrefix$keyId') ?? 0;
  }

  /// Deducts coins if redeemed locally
  static Future<void> consumeCoins(int amount, {String? uid}) async {
    final keyId = uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final currentBonus = prefs.getInt('$_bonusCoinsPrefix$keyId') ?? 0;
    final remaining = (currentBonus - amount).clamp(0, double.infinity).toInt();
    await prefs.setInt('$_bonusCoinsPrefix$keyId', remaining);
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
