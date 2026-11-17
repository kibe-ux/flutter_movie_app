# Abuse protection rollout

## Deployment status ? 17 November 2026

The Movie Hub API is deployed as Neon deployment **22** (Node.js 24), replacing
active deployment 21. Only `function:moviehub` changed; the cleanup function and
schedule were outside the deployment scope. App Check enforcement is off.
Omitted rewards/deletion settings now preserve their hosted values. Production
health, unauthenticated private-route rejection, retired-route rejection, deletion
page availability, and guest catalogue caching passed smoke checks. The deletion
page still reports automatic deletion disabled, matching its pre-deploy state.
The backend suite passed 124 tests (one integration test skipped), the database
connection check passed, and the production dependency audit found no advisories.

The forum cooldown rules and mobile app changes are **not published**. Distribute
the updated app and complete the Firebase App Check/device checks before publishing
rules or enabling enforcement. The backend deployment alone does not activate the
forum cooldown.

## What the code enforces

- Posts and replies share a 30-second per-account cooldown. Firestore checks the
  server timestamp and target ID in an atomic batch; direct writes, slot deletion,
  backdating, and multiple contributions using one slot are rejected. Likes and
  reports keep their existing rules. Account deletion also removes cooldown data.
- API ingress uses PostgreSQL buckets shared across instances: 3,000 requests per
  minute globally and 600 per socket peer. Rotating installation IDs or spoofing
  forwarding headers does not reset these ceilings. Missing credentials on private
  routes still return 401 without a database call.
- Rewards share 60 requests per account per minute; account deletion allows five.
  Quota failures return 429 with Retry-After; database failures reject requests with
  503. Existing provider budgets and per-installation limits remain in place.
- App Check support is opt-in. The mobile build sends tokens on catalogue,
  Wambesha, rewards and account requests. Firestore uses SDK App Check integration.
  Server verification uses the runtime Firebase project, including on guest requests.

## Release order

1. Deploy the backend with `APP_CHECK_ENFORCED=false`. Verify PostgreSQL access;
   these API quotas require the existing catalogue rate table.
2. Register Android with Play Integrity and the release signing SHA-256 in Firebase
   App Check. Register Apple App Attest and web reCAPTCHA v3 if releasing those
   platforms. Debug builds use Firebase's debug providers; register debug tokens
   only for development and do not ship or commit them.
The updated client checks cooldown-document access against the server on each
contribution. Before rules publication it sends the existing legacy batch; after
publication it includes the required cooldown slot. New rules reject legacy
batches, so this transition does not bypass the server cooldown. Network errors
stop the write rather than selecting legacy behavior.

3. Build the updated app with `--dart-define=APP_CHECK_ENABLED=true`. For web also
   supply `--dart-define=APP_CHECK_WEB_SITE_KEY=YOUR_PUBLIC_SITE_KEY`. Test the
   real release build and inspect App Check metrics before enforcing anything.
4. Distribute the updated app before publishing `firestore.rules`. Old builds do
   not send the contribution batch and cannot post/reply under the new rules.
   Coordinate a minimum supported version or a maintenance window; publishing
   the rules immediately will interrupt posting for existing installations.
5. After clients are ready, publish the tested rules, enable App Check enforcement
   for Firestore in Firebase, and set `APP_CHECK_ENFORCED=true` on the backend.
   Exercise guest browsing, sign-in, rewards and deletion on a physical device.

App Check is not required for the AdMob SSV callback (Google signature verified),
account deletion (browser flow uses verified Firebase identity and recent login),
or signed download streams (bearer JWT verified). API quotas still apply to those
requests. The public deletion page remains usable outside the mobile app.

## Hosting considerations

The Neon adapter currently reports a loopback peer rather than a verified client
IP. On that deployment the 600/minute peer ceiling is shared by all API callers.
It is a conservative service-wide safety cap, not a unique-device quota. Do not
trust arbitrary X-Forwarded-For values to split it; configure a verified hosting
client identity or gateway limits before scaling beyond that shared capacity.
Distributed bots can still consume shared capacity. Configure hosting-edge abuse
protection and monitor 429/503 rates and database costs. App Check complements
these limits; it does not eliminate abuse.

The cooldown limits contributions per account, not account creation. Email
verification and anti-spam moderation remain additional work. Email verification
and shorter download-link expiry were not changed in this rollout.

## Validation

Run `npm test` in backend, `flutter analyze`, `flutter test`, and `npm test` in
`tools/firestore-tests`. The rules emulator requires Java 21 or later. Tests use
local demo data and isolated rate stores, never production identities.

Official setup: https://firebase.google.com/docs/app-check/flutter/default-providers
