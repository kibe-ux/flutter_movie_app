# Native Google demo-ad diagnostic

This independent Android app reuses Movie Hub's debug-only `AdSdkProbeActivity`.
It includes no Flutter, Firebase, Film365, publisher ad units or backend keys.
It uses a separate diagnostic package, `com.moviehub.adsprobe`; Movie Hub's
production application ID is unchanged. Use it for diagnosis only.

From the repository root, with ANDROID_HOME set to the Android SDK directory:

```powershell
.\android\gradlew.bat -p tools/ad_sdk_probe --console=plain assembleDebug
adb install -r tools/ad_sdk_probe/build/outputs/apk/debug/AdSdkProbe-debug.apk
adb shell am start -n com.moviehub.adsprobe/com.moviehub.app.AdSdkProbeActivity --es testDeviceId YOUR_SDK_TEST_DEVICE_ID
adb logcat -s AdSdkProbe:I Ads:I
```

The test device value is the SDK hash printed in Google Ads logs, not the
Advertising ID entered in AdMob. All hardcoded units are Google demo units,
regardless of whether that optional SDK hash is supplied. No interstitial is
shown: the probe tests its load callback only.

To compare against the older ads SDK used with google_mobile_ads 5.3.1:

```powershell
.\android\gradlew.bat -p tools/ad_sdk_probe --console=plain '-PadSdkVersion=23.6.0' assembleDebug
```

Use `--ez restricted true` when launching to compare the app's Teen content
rating and non-child-directed request settings against the SDK defaults.
Force-stop the diagnostic app between comparisons. Do not use this app to
serve live ads or as a replacement package for Movie Hub.

The optional `'-PprobePackage=com.moviehub.app'` build property was used for a
controlled, temporary comparison. It replaces the installed Movie Hub APK if
installed, so the full Movie Hub APK must then be restored with `adb install -r`.
Do not uninstall Movie Hub or clear its data for this comparison.
