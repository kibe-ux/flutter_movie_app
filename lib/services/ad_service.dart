import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  int _interstitialClickCount = 0;
  static const int _interstitialFrequency = 3; // Show every 3rd click/action

  String get bannerAdUnitId => dotenv.env['ADMOB_BANNER_ID'] ?? 'ca-app-pub-3940256099942544/6300978111';
  String get interstitialAdUnitId => dotenv.env['ADMOB_INTERSTITIAL_ID'] ?? 'ca-app-pub-3940256099942544/1033173712';

  Future<void> init() async {
    if (_isInitialized) return;

    final isPremium = await _isPremiumUser();
    if (isPremium) return;

    final params = ConsentRequestParameters();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadConsentForm();
        } else {
          _initializeAds();
        }
      },
      (FormError error) {
        debugPrint('Consent update failed: ${error.message}');
        _initializeAds();
      },
    );
  }

  void _loadConsentForm() {
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show(
            (FormError? formError) {
              _loadConsentForm(); // Reload if needed or just initialize
              _initializeAds();
            },
          );
        } else {
          _initializeAds();
        }
      },
      (FormError formError) {
        debugPrint('Consent form load failed: ${formError.message}');
        _initializeAds();
      },
    );
  }

  void _initializeAds() {
    MobileAds.instance.initialize();
    _isInitialized = true;
  }

  Future<bool> _isPremiumUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_premium_user') ?? false;
  }

  /// Show interstitial with frequency control
  Future<void> showInterstitial(InterstitialAd? ad, Function onAdDismissed) async {
    final isPremium = await _isPremiumUser();
    if (isPremium) {
      onAdDismissed();
      return;
    }

    _interstitialClickCount++;
    if (ad != null && _interstitialClickCount % _interstitialFrequency == 0) {
      ad.show();
      onAdDismissed();
    } else {
      debugPrint('Ad skipped due to frequency control (Count: $_interstitialClickCount)');
      onAdDismissed();
    }
  }
}
