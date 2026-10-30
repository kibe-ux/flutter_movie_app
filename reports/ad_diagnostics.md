# Movie Hub ad diagnostics — 30 October 2026

## Latest result: controlled package comparison, 12:13–12:24 EAT

The failure is associated with Movie Hub's package/app state rather than the
Film365 client, Flutter ad flow, demo IDs, SDK version alone, or this phone's
general ability to load ads. A package-associated serving rejection is now
the leading explanation; Google's exact rejection reason remains unknown.

All comparisons used the same Samsung A31, SDK 25.5.0, Google sample app ID,
fixed-size banner sample and interstitial sample, and debug signing certificate.
The independent native probe has no Flutter, Firebase, Film365, backend key,
publisher units, or mediation dependencies. Interstitials are loaded only.

| Comparison | Banner | Interstitial |
| --- | --- | --- |
| Native diagnostic inside Movie Hub, SDK defaults, 12:13 | HTTP 403 | HTTP 403 |
| Independent native sample, `com.moviehub.adsprobe`, registered test device, 12:18 | Loaded | Loaded |
| Same sample with Teen rating/non-child-directed flags, 12:18 | Loaded | Loaded |
| Native diagnostic inside Movie Hub with explicit test-device registration, 12:20 | HTTP 403 | HTTP 403 |
| Identical minimal sample installed as `com.moviehub.app`, 12:22 | HTTP 403 | HTTP 403 |
| Same `com.moviehub.app` sample with refreshed `admob.xml` SDK cache, 12:23 | HTTP 403 | HTTP 403 |
| Repeated independent sample `com.moviehub.adsprobe`, 12:24 | Loaded | Loaded |

The success/failure/success comparison substantially narrows the issue to
package identity or remaining package-associated device/server state.
Changing the main package is not a proposed production fix. The temporary
minimal replacement and ad SDK preference reset were reversed: the full
Movie Hub APK and original `admob.xml` are restored, without clearing app
data. Movie Hub's normal activity was opened again. The standalone diagnostic
app is installed separately for further testing.

Success response IDs include `2WDkarCQHPGk9fgPxOzywAw` (12:18:19),
`92Dkaq2tHdnh-LoP4ZuOkQw` (12:18:48), and `RmLkaof_JduN9fgP_t3uuAI`
(12:24:23). Failed requests have no response ID and no adapter responses.
Filtered evidence is saved in `admob-native-comparison-2026-10-30.log`.

### Timeline and limits

The owner says ads worked before applying the Film365 key. Git history shows
the sample app/banner/interstitial IDs were already used in January. Commit
`4427fd9` records a package change from `com.example.movie_app` to
`com.moviehub.app`, alongside substantial ad/startup and catalogue changes.
Earlier source also contained a separate Kotlin Gradle file using
`com.example.movie_hub`; the exact last-working installed package/build is not
available. A commit date does not establish when an uncommitted edit occurred.

The native comparison reproduces the failure with no Film365 code or key
present. This excludes a direct Film365 client-code requirement, but cannot
determine whether historical app/account activity influenced Google's serving
decisions. It does not prove an account ban, policy violation, app-readiness
restriction, or a particular cause of package rejection. Other per-package
device state has not been fully erased; app data was intentionally preserved.

The phone's automatic time/time-zone settings were enabled, no HTTP proxy was
configured, and its system hosts file contained only localhost entries.
The matching-settings sample succeeds, so an SDK downgrade is not presently
justified as the next diagnostic step.

### Next action

Provide Google AdMob/SDK support with the failing package and this controlled
comparison, and ask them to investigate the package-associated HTTP 403.
An updated support draft is in `admob-support-draft.md`; nothing has been sent.
The account's policy/readiness status should be supplied by the owner because
it cannot be verified from repository or device logs.

## Earlier diagnostic history

Update from the 12:04 Africa/Nairobi retest: the fixed-size Google demo banner
`ca-app-pub-3940256099942544/6300978111`, requested as `AdSize.banner`
(320 x 50), also returns HTTP 403. The demo interstitial remains affected.
The updated debug APK was built and installed successfully. All 26 targeted
configuration, ad-service and banner tests passed. Analysis of the modified
source files found no errors and one existing adaptive-size API deprecation.

The project uses Flutter 3.47.7 from `C:\Users\Hezra\.android\flutter`.
The older Flutter installation on PATH caused the earlier native-assets test
failure; using the project SDK resolved that test environment issue.

The earlier 11:44 retest confirmed cellular data as the active default network,
with Private DNS off, and reproduced HTTP 403. Google logs recognized test
requests. Switching away from the PC hotspot did not resolve the error.
The 12:04 request logs again confirm `ready=true mode=test` and recognition of
a test device; the fixed-size banner and interstitial both failed at 12:04:36.
Neither an account restriction nor a device-specific or Google-side cause has
been established. The sample-ID change is a tested diagnostic comparison,
not a confirmed fix for the HTTP 403 failure.

The Google demo banner and interstitial requests still fail with SDK error code 3 and `Received error HTTP response code: 403` after upgrading the ads plugin and reinstalling the application.

## Verified configuration

- Physical Android phone: Samsung SM-A315F, Android 12.
- Package: `com.moviehub.app`.
- Debug build; Google demo app/ad unit IDs remain selected.
- Google logs confirm: `This request is sent from a test device.`
- Mobile Ads initialization completes with `ready=true mode=test`.
- Plugin upgraded from `google_mobile_ads` 5.3.1 to 9.2.0.
- Updated plugin declares legacy Android Mobile Ads SDK 25.5.0.
- New debug APK built, installed successfully, and application restarted.
- 47 configuration, inspector, ad flow, banner, and rewards tests pass.
- Analyzer reports no errors; three compatibility API deprecation notices remain.

## On-device evidence after the update

Fresh process 7076, 30 October 2026, Africa/Nairobi:

- 00:52:01 — Ads initialized, ready=true, mode=test.
- 00:52:01 and 00:52:05 — Google recognizes a test device.
- 00:52:06 — Interstitial: code=3, domain=com.google.android.gms.ads, HTTP 403.
- 00:52:06 — Home banner: code=3, domain=com.google.android.gms.ads, HTTP 403.

Ad Inspector shows the failed demo ad unit requests as No Fill, with HTTP 403 in the request details. Its WebView also logs `Failed to compare SDK versions`; the inspector's direct default-ad test has not produced a conclusive independent result.

## Remaining uncertainty

The hotspot/mobile-data comparison was subsequently completed and both
failed. The independent native sample comparison above now narrows the issue
further; the exact Google-side reason and other per-package device state
remain unverified.

## Next diagnostic step

The earlier recommendation to compare internet connections is complete.
See the latest controlled comparison and next action at the top of this report.

Update: the separate-connection check is complete and still fails. A support
draft is available in `admob-support-draft.md`. No report has been sent.
