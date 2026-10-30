# Cinema Rewards implementation and activation

## Current test-only mode

Google's platform-specific demo ad units remain the default. The owner clarified that real units must be selectable later through configuration. Debug/profile builds always use test ads. A release build can select publisher units when `ADMOB_USE_TEST_ADS=false` and all three configured unit IDs are valid publisher IDs. Incomplete or sample values keep all formats in test mode. Android/iOS native app IDs currently remain Google's sample IDs.

Signed-in users can choose **Watch test ad** in Cinema Rewards without an activated reward backend. The confirmation explains that this is a preview with no spendable coins. Demo completion does not create a backend reward session or grant coins. Existing earned balances and redemptions remain server-owned.

Future production ad activation requires no ad-selection code change: replace the three Flutter ad unit values for the target platform, set `ADMOB_USE_TEST_ADS=false`, update the native AdMob app ID and rebuild in release mode. Actual coin earning additionally requires the backend/SSV/consent setup below. The earlier preview image depicts the intended live earning screen rather than the current test-preview wording.

## Experience

Cinema Rewards is an optional drawer destination in the existing burgundy/gold palette. Guests see an invitation to sign in and can keep browsing. Only real signed-in accounts can access a wallet, reward sessions or redemptions; anonymous Firebase accounts are excluded.

The server defines the economy: one completed verified rewarded ad earns 10 coins. Offers are 30 coins for 1 hour, 80 for 3 hours and 150 for 6 hours without banner/interstitial ads. The screen discloses the required action and reward before each ad, with an equally functional Not now choice. There is no autoplay, streak, random reward, cash-out, purchase, transfer or requirement to watch for normal movie access. Ad-free duration starts on redemption, continues while the app is closed, and additional passes extend an existing expiry. Watching is disabled while a pass is active.

## Trust and persistence

- Firebase bearer authentication is reused unchanged for wallet/session/cancel/redeem routes. There is no client coin-credit API.
- `GET /api/rewards/ssv` is a public provider callback authenticated by its ECDSA SHA-256 signature. It verifies the original query bytes against Google's HTTPS public-key feed, rejects duplicate parameters and binds the callback to a server-issued session, signed-in UID, allowlisted ad unit and event time.
- Firestore transactions bind coins to the account, mark each reward session once, record unique provider transaction receipts and atomically spend coins/extend expiry. Redemption request IDs make retries idempotent within the app session. If an HTTP response is lost and the app is restarted, refresh the wallet before redeeming again.
- Cancelled or expired display sessions retain their original ledger record so a delayed legitimate callback can still pay. Duplicate callbacks never pay twice. The current pending session is cleared only by its own completion/cancellation/expiry.
- The client SDK earned callback triggers confirmation polling; it cannot grant coins or ad-free time. Unconfirmed rewards stay pending with refresh guidance. Mobile callbacks/loading failures preserve balances.
- Ad-free state comes only from the authenticated backend, is cleared on account changes, is refreshed at sign-in/app resume/rewards-screen refresh, and uses server-relative duration measured by a monotonic stopwatch. Expiry invalidates ad suppression, removes active banners immediately and restores ordinary ads after expiry. No coins or paid entitlement are trusted from SharedPreferences. Existing separate premium behavior remains respected.
- State is restored from the backend after app restart; offline cold starts cannot restore a verified pass until the server is reachable. A pass redeemed on another device is recognized on the next refresh/resume. Existing server download authentication remains unchanged.

## Not activated yet

No real `.env`, credentials, Firebase rules, AdMob console settings or deployed resources were changed. No live ad was requested, no live coins were issued and no deployment was performed. The existing test-ad preference remains in place. Until activation, the screen shows that rewards are being prepared and does not present rewarded ads or promise spendable coins from Google's demo ads.

Activation requires:

1. Deploy the reviewed backend with existing Firebase ADC permissions for Firestore. The new collections are `reward_accounts` (including redemption receipts), `reward_sessions` and `reward_receipts`.
2. Review/merge `backend/rewards.rules.fragment.txt` so mobile/web clients cannot read/write reward records directly. In particular, a broad permissive wildcard overrides narrower deny rules. Test this in the rules emulator. Keep the app's existing forum/profile rules intact. Only the backend should have wallet write access.
3. Create the Android/iOS publisher **rewarded** ad units (not rewarded interstitials). Configure server-side verification to the public HTTPS URL `https://YOUR_BACKEND/api/rewards/ssv`. The SDK supplies user ID and session ID; do not add fixed query parameters or configure a client-returned amount.
4. Add the publisher unit IDs to server `ADMOB_REWARDED_UNIT_IDS`, the platform's Flutter `ADMOB_REWARDED_ID`, and only after verification set server `ADMOB_REWARDS_ENABLED=true`. Configure production UMP messages/IDs as in the existing policy review. Debug/test mode keeps using Google's demo units; do not enable an unfulfillable coin offer using demo units. To validate production SSV in development, use your publisher unit in a controlled test-device setup; do not disable testing safeguards or click live ads.
5. Verify a complete native-device opt-in/completion -> signed callback -> wallet -> redemption -> banner/interstitial suppression -> expiry flow. Verify dismissal, no fill, consent denial/change, app background, account switch, duplicate callbacks, pending rewards and service outages. Google's sample units cannot be configured with your publisher callback URL and do not prove that your server receives SSV.
6. Keep private ledger records for durable deduplication and delayed reconciliation; choose a retention/cleanup policy before public release. Update the hosted privacy policy/Data Safety disclosures for account-linked reward balances, verified ad events and redemption records. Add operational monitoring/reconciliation for callbacks that fail verification or never arrive so earned rewards can be delivered. This code does not provide a support/admin reconciliation UI.

The enable flag is an operator-controlled activation gate, not automated proof of correct rules, callbacks, UMP setup or policy approval. Broader app content licensing, moderation and regional/age consent requirements from the earlier policy review still apply.

## Policy references checked

- [Google policies for ad units offering rewards](https://support.google.com/admob/answer/7313578?hl=en): affirmative opt-in, conspicuous action/reward disclosure, functional dismissal, no harm to ordinary usage, reward delivery, and account-bound non-monetary in-app rewards.
- [Flutter rewarded ads](https://developers.google.com/admob/flutter/rewarded): test inventory, native lifecycle and server verification options.
- [SSV verification](https://developers.google.com/admob/android/ssv): signed query format, public-key rotation, transaction IDs and provider retry behavior.

## Validation completed

- 29 Flutter rewards/ad tests passed, covering the wallet, account changes, opt-in/cancel UI, redemption retries, timed interstitial suppression and existing banner/interstitial behavior.
- 10 backend rewards tests passed, including guest/anonymous route rejection, exact-byte ECDSA verification, duplicate callbacks, session/account binding, late callbacks and concurrent/idempotent redemptions. The existing backend suite also passed.
- Guest-entry and splash-startup regression checks passed. Dart analysis of the changed implementation and tests found no issues; Node syntax and diff whitespace checks passed.

Tests use HTTP/SDK/storage doubles and locally generated cryptographic keys. They do not establish live AdMob approval, actual callback delivery, deployed Firestore security or native rendering.
