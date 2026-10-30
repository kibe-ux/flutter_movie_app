import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:moviehub_app/services/ad_diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = MethodChannel('plugins.flutter.io/google_mobile_ads',
      StandardMethodCodec(AdMessageCodec()));
  final calls = <String>[];
  var fail = false;
  setUp(() {
    calls.clear();
    fail = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'MobileAds#initialize') return InitializationStatus({});
      if (call.method == 'MobileAds#openAdInspector' && fail) {
        throw PlatformException(
            code: 'NOT_IN_TEST_MODE',
            message: 'Register the device as a test device.',
            details: 'ad-inspector');
      }
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('configures and initializes the SDK before opening the inspector',
      () async {
    await AdDiagnostics.openInspector();
    expect(
        calls,
        containsAllInOrder([
          'MobileAds#updateRequestConfiguration',
          'MobileAds#initialize',
          'MobileAds#openAdInspector',
        ]));
  });

  test('inspector errors reach the caller with an actionable message',
      () async {
    fail = true;
    await expectLater(
        AdDiagnostics.openInspector(),
        throwsA(isA<StateError>().having((error) => error.message, 'message',
            contains('Register the device'))));
  });

  test('normal startup does not open developer diagnostics', () async {
    await AdDiagnostics.openOnRequest();
    expect(calls, isEmpty);
  });
}
