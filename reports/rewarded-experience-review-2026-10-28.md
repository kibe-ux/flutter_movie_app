# Cinema Rewards: presentation, user choice and revenue review

## Changes implemented

- Reworked the screen around an account balance card, a restrained metallic coin illustration, burgundy header, champagne accents and compact ad-free pass cards. No extra image asset or dependency is required.
- Progress and pass availability come from the actual server wallet and offer costs. There are no fabricated popularity badges, earnings claims, countdowns, streaks or urgency prompts. Prices and earned balances were not changed.
- Test mode is prominent. The watch control explicitly says Watch test ad, and both the screen and confirmation disclose that it adds no spendable coins or revenue. All formats remain locked to Google's demo ad units, including release builds.
- Added distinct loading, presentation, confirmation and redemption states. Buttons remain disabled during the operation and repeated requests are guarded. Failed ad loads have safe SDK diagnostics for troubleshooting no-fill/connection problems; no personal data or tokens are logged.
- Confirmation dialogs use the same palette, have functional Not now/Cancel choices, and allow scrolling with large text. A small-screen/large-text regression test exercises the balance, watch control and pass controls.
- Ads still load only after explicit acceptance. Leaving the screen before loading finishes prevents late presentation. There is no automatic replay or automatic rewarded ad after dismissal.

## What can improve revenue, and what is unproven

Clear value, readable choices and understandable loading/failure states may reduce friction for users who voluntarily choose rewards. That is a design hypothesis; no revenue increase has been measured or promised. Test ads generate no publisher earnings, and neither live units nor new analytics/mediation services were enabled.

Once production activation is separately authorized and the backend/SSV/consent setup is verified:

1. Use AdMob's rewarded reports to compare rewarded users, impressions, show rate, eCPM and revenue per active user. Investigate loading/no-fill failures before changing reward prices. App ledger receipts indicate verified grants, not ad revenue.
2. Evaluate total ad revenue and retention together. A pass suppresses other ad opportunities, so more rewarded views alone do not establish better overall earnings. Compare against the banner/interstitial revenue forgone during ad-free hours.
3. Test reward/offer changes prospectively in a controlled experiment with clear disclosure. Preserve already-earned coins and active passes; do not change the economy based on guesses or country income assumptions.
4. Evaluate AdMob mediation/bidding only after production consent/privacy and each network's test setup are reviewed. It may improve available demand; it does not guarantee a higher eCPM or total revenue. No mediation adapters/configuration were added here.
5. Keep every viewing decision optional, enforce reward delivery/reconciliation, and never ask users to click ads, install promoted apps, make purchases or view ads to support the publisher. Ordinary browsing remains independent of rewards.

## Policy boundaries

The implementation follows the reviewed requirements for affirmative opt-in, conspicuous action/reward disclosure, functional dismissal, normal access after decline and non-transferable in-app rewards. Coins have no cash value or transfer/cash-out mechanism. The existing server-only credit and idempotent redemption design remains intact.

This is not Google approval or a guarantee of compliance. Live review still includes actual rendering, consent/age/region settings, reward delivery, content distribution rights and the forum's moderation requirements. See the existing AdMob and Cinema Rewards activation reviews. No credentials, cloud rules, publisher settings or deployments were changed in this update.

## Primary sources checked

Validation: 33 targeted Flutter tests passed across the wallet, screen, interstitial and banner suites, including small-screen/200% text scaling, explicit opt-in/cancellation and ad activity transitions. Dart analysis found no issues. Native-device rendering and live earnings were not measured.

- [Policies for ad units offering rewards](https://support.google.com/admob/answer/7313578?hl=en)
- [Flutter rewarded ad lifecycle](https://developers.google.com/admob/flutter/rewarded)
- [Rewarded video best practices](https://admob.google.com/home/resources/best-practices-for-in-app-rewarded-video-ads/)
- [AdMob and Firebase metrics](https://firebase.google.com/docs/admob/)
- [User activity reports](https://support.google.com/admob/answer/10200963?hl=en-topic)
