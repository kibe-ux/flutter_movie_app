# AdMob implementation review — 28 October 2026

## Scope and result

Current configuration: banner, interstitial and rewarded placements default to Google's demo units. Real IDs can be selected later using the Flutter environment settings in a release build; incomplete configuration and non-release builds retain test ads. Cinema Rewards offers a signed-in test-ad preview that never grants spendable coins. No live ads or backend earning have been activated.

Reviewed the Flutter ad request flow, banner placements, interstitial triggers, consent controls, and privacy disclosures against Google's published guidance. The owner confirmed a general audience aged 13+. The app remains configured for Google test ads. No production IDs, credentials, deployments, or external account settings were changed.

This is an implementation review, not Google approval or a guarantee of compliance. On-device rendering, account settings, content distribution rights, and store declarations remain unverified.

## Changes made

- Moved Home and Explore banners from directly above the bottom navigation to a dedicated area at the top of their content. The carousel implementation is unchanged.
- Added 24 logical pixels of noninteractive space above and below banner creatives. This is an app design choice, not a Google-specified minimum or a guarantee against accidental clicks.
- Reserved the measured banner slot while requests load or retry, so a successful load does not insert a new block between app controls. Ads remain separate from content and never overlay it.
- Home and Explore do not mount banners for loading-only, empty-list, or error-only states.
- Interstitials now require an explicitly eligible browsing transition. Generic actions, movie/episode download starts, and downloaded-video playback proceed without an interstitial.
- Added a 60-second session warmup, at least two browsing actions between shown ads, and a two-minute cooldown measured from dismissal. View All is an ad opportunity, while poster opens have a separate counter that makes the third, sixth, ninth, and subsequent multiples of three eligible. View All does not advance the poster counter; ignored or cancelled poster taps do not count as opens. These are conservative app limits; Google does not prescribe these exact time values.
- Only already-loaded interstitials may show at the transition. Navigation never waits for SDK initialization or a network ad load, and late loads cannot suddenly present themselves.
- Added a foreground check before presentation. No automatic interstitials are triggered at launch, resume, exit, or during playback.
- Production ad initialization continues to use Google's UMP consent update and required form. Added **Ad privacy choices** to the Privacy Center when UMP reports that the entry point is required. It is intentionally absent with Google's demo app configuration in test mode.
- Opening privacy choices suspends requests, invalidates cached/pending creatives, and removes displayed banners. Requests resume only after reinitialization checks UMP permission again.
- Added a Teen maximum ad-content rating and a non-child-directed declaration based on the owner's stated audience. This is not an age-verification mechanism and does not assert that every user is above their region's age of consent.
- Expanded the in-app privacy notice to describe advertising identifiers, IP addresses, interactions, diagnostic data, and privacy choices.

## Still required before live ads

1. Verify that the app is authorized to distribute or link to every offered movie/episode download. The repository's third-party links and disclaimers do not establish those rights. Google prohibits copyright-infringing content; moving ads or showing a disclaimer does not resolve a content-rights issue.
2. Match AdMob and Play audience declarations to the actual 13+ audience. Assess regional age-of-consent handling for teenage users before live service. The current UI does not collect an age that could determine an individual user's under-age-of-consent treatment.
3. Configure actual publisher app IDs/ad units and the necessary UMP messages in AdMob, then verify required consent and privacy-choice behavior using Google's test tooling. The current sample app IDs cannot validate publisher-specific consent messages.
4. Publish an accurate accessible privacy-policy URL and complete store privacy/data-safety declarations, including any analytics, crash reporting, Firebase, and advertising data flows. An in-app page alone does not validate store/account declarations.
5. Test real Android/iOS layouts across screen sizes, orientation changes, and larger text. Confirm separation from controls, stable reserved space, unobstructed SDK close controls, and that no ads appear over dialogs, playback, error-only pages, or background screens. No device was available for this review.
6. Validate actual catalog listings and content moderation. Ad-content filtering controls advertiser creatives; it does not certify the app's own film artwork, downloads, or user-generated forum content.
7. Keep all development and QA traffic on test inventory. Do not click live ads to test them or ask users to click ads. No incentives, custom close buttons, forced ad clicks, or rewards for ordinary interstitials were added.

The previously generated banner mockup showing an ad directly above bottom navigation is a design illustration and no longer represents the revised placement. Advertiser artwork and close controls are supplied by the SDK; no generated image is used as an actual ad.

## Sources

- [Google: disallowed interstitial implementations](https://support.google.com/admob/answer/6201362?hl=en)
- [Google: discouraged banner implementations](https://support.google.com/admob/answer/6275345?hl=en)
- [Google: Flutter UMP integration](https://developers.google.com/admob/flutter/privacy)
- [Google: ad request targeting and content ratings](https://developers.google.com/admob/flutter/targeting)
- [Google: intellectual property abuse policy](https://support.google.com/publisherpolicies/answer/10402772?hl=en-GB)
- [Google Publisher Policies](https://support.google.com/publisherpolicies/answer/10502938?hl=en)
