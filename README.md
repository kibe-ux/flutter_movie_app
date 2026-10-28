# flutter_application_1

A new Flutter project.

## Android release signing

Release builds use the private keystore configured in `android/key.properties`.
Fill in `storePassword` and `keyPassword` locally before building. If the key
uses the keystore password, enter that same password in both fields. Use forward
slashes in the keystore path. Java properties files require literal backslashes
in passwords to be escaped as `\\`.

The properties file and `.jks`/`.keystore` files are ignored by Git. Back up the
keystore and passwords securely. Release builds fail when signing configuration
is missing; debug builds retain their development signing key.

Before distributing a release, register its SHA-1 and SHA-256 certificate
fingerprints with Firebase and test Google sign-in. A release signed with this
key cannot normally update an existing debug-signed installation. Preserve local
downloads before uninstalling a development build.

## Ads and launch sequence

The app currently uses Google's sample AdMob app IDs and test ad units.
`ADMOB_USE_TEST_ADS=true` in the root `.env` keeps release builds on test ads;
debug builds always use test ads. These ads are for testing the placements.

Poster taps, Home's **View All**, and confirmed movie or episode downloads
share one interstitial service. Actions continue after dismissal or presentation
failure. Missing ads and load timeouts allow the action to continue; an ad that
loads later is saved for a future action. A shared 45-second cooldown avoids
back-to-back ads, including between opening a poster and starting its download.
Pause/resume do not interrupt downloads with ads.

Cold launch shows the app logo on black, then the cinematic splash, then the
authentication or home screen. The Flutter logo lasts one second; the cinematic
splash stays visible for at least 1.4 seconds and waits for startup data when
necessary. Returning from the background does not restart this sequence.

Install a fresh APK to test native launch changes; hot reload cannot update
Android launch resources. Force-stop and reopen the app, tap a poster, close the
test ad, and verify the details screen opens. After the cooldown, test **View All**
and a confirmed download. With no ad available, both actions should still work.

Focused checks:

```sh
flutter test test/services/ad_service_test.dart test/screens/logo_screen_test.dart test/screens/splash_screen_test.dart test/screens/category_pagination_test.dart test/screens/responsive_layout_test.dart
```

## Crash reporting

Firebase Crashlytics reports Flutter framework errors and uncaught asynchronous
errors after Firebase initializes. Caught app and ads initialization failures
are recorded as non-fatal errors. Other caught errors can be reported with
`CrashReportingService.recordError(error, stack, reason: 'operation failed')`.
Firebase initialization failures themselves cannot be sent to Crashlytics.

Collection is enabled in release builds and disabled in debug/profile builds.
Override this with `--dart-define=CRASHLYTICS_ENABLED=true` (or `false`).
Web, Windows and Linux skip Crashlytics initialization.

To verify on an Android device:

1. Run `flutter run --dart-define=CRASHLYTICS_ENABLED=true` using the project's
   Flutter SDK (on this machine, `C:/Users/Hezra/.android/flutter/bin/flutter.bat`).
2. After startup, temporarily invoke
   `CrashReportingService.recordError(StateError('Crashlytics setup test'), StackTrace.current, reason: 'Manual setup verification')`
   from a local debug action, then remove that action.
3. Check **Firebase Console > my-flutter-app-hezra-202-12dc9 > Crashlytics**
   for the non-fatal event. Native fatal crash testing can use
   `FirebaseCrashlytics.instance.crash()` in a temporary debug action; reopen
   the app afterward to upload the report. Allow several minutes for delivery.

Android applies the Crashlytics Gradle plugin. The app's current
`firebase_options.dart` has no iOS or macOS configuration. Before building for
Apple platforms, configure those apps with `flutterfire configure` on a Mac;
this also installs their Crashlytics symbol-upload build phases. Apple crash
reporting requires that Firebase setup and validation on macOS.

Google Analytics is already included. Enable Google Analytics in the Firebase
project to receive Analytics breadcrumbs in Crashlytics reports. See the
[Firebase Flutter setup guide](https://firebase.google.com/docs/crashlytics/flutter/get-started).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
