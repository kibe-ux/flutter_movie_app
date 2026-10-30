# Google demo ad units return HTTP 403 on Android

## Important update: failure follows package identity/app state

We have now reproduced this in a minimal native Android sample containing
only the Google Mobile Ads SDK and a single Activity. No Flutter, Firebase,
Film365, publisher ad units, backend keys, or third-party mediation code is
included. Both packages use the same debug signing certificate.

- `com.moviehub.adsprobe`: banner and interstitial load successfully.
- The same minimal sample built as `com.moviehub.app`: both return HTTP 403.
- Explicit SDK test-device registration is enabled in both cases.
- Teen content rating/non-child-directed settings also work in the successful
  package, so those app request settings do not explain the difference.
- Refreshing only `shared_prefs/admob.xml` in the failing package does not help.
- Repeating the successful package after the failures again loads both ads.
- SDK: 25.5.0 throughout. Same device and network for these comparisons.

Failed requests have response ID null and no adapter responses. Successful
response IDs: `2WDkarCQHPGk9fgPxOzywAw` at 12:18:19,
`92Dkaq2tHdnh-LoP4ZuOkQw` at 12:18:48, and
`RmLkaof_JduN9fgP_t3uuAI` at 12:24:23 on 30 October 2026, EAT (UTC+3).

Movie Hub previously used a `com.example` package according to source history;
the owner reports ads worked before a period of catalogue/app changes. We do
not have the exact last-working APK. We have not changed the production
package to work around the failure. The full app and original SDK settings
were restored after the temporary native comparison, preserving app data.

Please investigate whether requests associated with `com.moviehub.app` are
being rejected by serving configuration or a restriction, and explain the
specific reason. We cannot infer the exact server-side cause from HTTP 403.
Other per-package device state has not been fully cleared.

## Original reproduction details

Please help investigate HTTP 403 failures with Google-provided demo ad units.

- App package: `com.moviehub.app`.
- Physical device: Samsung SM-A315F, Android 12.
- Flutter: 3.47.7; google_mobile_ads: 9.2.0.
- Ad Inspector reports Google Mobile Ads SDK 25.5.0.
- Android demo app ID: `ca-app-pub-3940256099942544~3347511713`.
- Adaptive banner demo ID: `ca-app-pub-3940256099942544/9214589741`.
- Fixed-size banner demo ID: `ca-app-pub-3940256099942544/6300978111`.
- Interstitial demo ID: `ca-app-pub-3940256099942544/1033173712`.

Both banner demo IDs were tested. The fixed-size unit uses AdSize.banner
(320 x 50). All requests use Google demo inventory, without mediation.
SDK initialization completes, and logs say the request is from a test device.
Ad Inspector shows No Fill and `Received error HTTP response code: 403`.

The failure reproduces over a PC hotspot and cellular mobile data. Private DNS
was off during the cellular check. Updating the plugin and reinstalling the
APK did not resolve the failure. An alternate phone/emulator comparison has
not been completed; the same-device native package comparison above is now
available instead.

Latest reproduction: 30 October 2026, Africa/Nairobi (UTC+3):

```text
12:04:31 Ads initialized ready=true mode=test
12:04:32 This request is sent from a test device.
12:04:36 Interstitial load failed: code=3 domain=com.google.android.gms.ads message=Received error HTTP response code: 403
12:04:36 Ads banner failed placement=home code=3 domain=com.google.android.gms.ads message=Received error HTTP response code: 403
```

The publisher reports reactivating an account after inactivity, but all captured
requests above use Google's sample app and unit IDs. We have not established
that the account state causes this error.

Can you investigate why these sample requests receive HTTP 403, and advise
what additional request diagnostics or a minimal reproduction you need?

This is a draft only; no support message has been sent.
