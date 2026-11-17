import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  static const enabled = bool.fromEnvironment('APP_CHECK_ENABLED');

  static Future<void> initialize() async {
    if (!enabled) return;
    const webKey = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');
    if (kIsWeb && webKey.isEmpty) {
      throw StateError('APP_CHECK_WEB_SITE_KEY is required.');
    }
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      webProvider: kIsWeb ? ReCaptchaV3Provider(webKey) : null,
    );
  }

  static Future<Map<String, String>> headers() async {
    if (!enabled) return const {};
    final token = await FirebaseAppCheck.instance.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('App verification unavailable.');
    }
    return {'X-Firebase-AppCheck': token};
  }
}
