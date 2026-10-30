# Android Google sign-in configuration repair

Date: 30 October 2026

## Confirmed configuration mismatch

- Package: `com.moviehub.app`.
- Firebase project: `my-flutter-app-hezra-202-12dc9`.
- Firebase Android app: `1:609797109604:android:c0b4d1225c1a0f2bf12c71`.
- Before this repair, Firebase listed only the older SHA-1
  `21:33:17:88:5F:64:66:52:12:3A:28:2E:48:98:64:9E:F6:02:D8:88`
  and its SHA-256. The currently installed debug build uses a different
  certificate, verified from the debug APK with Android apksigner.
- The Google identity provider is enabled. Its public web client ID matches
  the web client in the Android Firebase configuration.

## Changes applied

Registered the current debug signing fingerprints in Firebase, retaining the
existing fingerprints:

```text
SHA-1: B2:73:BC:28:A3:D1:1B:2B:EC:DA:D4:E3:9B:59:01:B5:CD:72:DC:2D
SHA-256: 93:B1:4B:C7:76:B6:EF:80:77:7E:48:6D:F9:85:FD:07:FE:13:EE:25:57:EA:88:08:8F:F7:0E:7D:CC:31:C7:A8
```

Downloaded fresh `android/app/google-services.json` from Firebase and verified
that it contains a new Android OAuth client for the current package and SHA-1.
Added debug-only Google sign-in error code logging, without logging tokens,
account details, or raw exception messages.

## Validation

Eight Google authentication service and login screen tests passed, covering
token exchange, missing identity tokens, cancellation, successful navigation,
network errors, and guest access.

The analyzer reported no issues in the authentication service and login
screen. The Android debug APK rebuilt successfully and was installed on the
connected Samsung A31 with `adb install -r`, preserving app data.

The missing certificate is a confirmed Google sign-in configuration defect.
Successful authentication on the physical device still requires the owner to
select their Google account after installing the rebuilt app. The earlier
generic error message did not expose the underlying Google status code, so
there is no captured pre-repair status proving it was the sole cause.

Register the actual release or Play App Signing certificate when distributing
that build; the fingerprints above belong to this development build.
