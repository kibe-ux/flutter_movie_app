# Account deletion rollout

## Production state

The later App Check, shared rate-limit and usage-monitoring extension was
reverted at the owner's request. Account deletion, its external verification
page, its dedicated runtime permissions and five-minute retry worker are kept,
along with forum reporting, blocking and moderation. Historical API-security
test results below are evidence of earlier checks, not active feature claims.
The rollback is deployed as API 9 and worker 7; a new disposable production
account was successfully deleted after removing the rate-limit schema. See
`account-forum-rollback.md` for current verification.

The deletion API and external verification page are deployed to existing Neon
project `summer-shadow-58564268`, branch `br-empty-forest-b4htkwt9`. Firebase
remains `my-flutter-app-hezra-202-12dc9`, with Firestore in Johannesburg
(`africa-south1`). Billing was not enabled.

Public page:
<https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech/delete-account>

`ACCOUNT_DELETION_ENABLED=true` is deployed after owner-confirmed real Google
sign-in, passing integration/browser tests, public access checks and successful
scheduled worker runs. The owner saw the verified-account screen; their deletion
attempt before activation returned the disabled-service error and did not start
cleanup. No owner account was deleted during rollout. Public HTML/module return
200 with CSP; unauthenticated deletion returns 401; both public and forged-header
worker calls return 403. The API-security rollout subsequently created and
deleted its own disposable production account, verified that login was rejected
afterward and confirmed removal of its SQL rate counters. The production check
did not seed forum/reward records; their detailed data isolation/cleanup is
covered by real emulator integration. Installed-app deletion remains unverified.

The `accountcleanup` function has `ACCOUNT_DELETION_WORKER_ENABLED=true` and
trigger `account-deletion-retries`, scheduled `*/5 * * * *` UTC. A genuine run
succeeded at 2026-10-31 09:00:07 UTC, with zero pending jobs. Worker deployment 4
also succeeded at 09:15:05 UTC. Activation deployed API 7 and worker 5 at
09:17:15 UTC (12:17:15 in Nairobi); public activation/access checks passed. The
later API-security rollout deployed API 8 and worker 6 with deletion still enabled. Reports under
`reports/account-deletion-rollout/` record verification and deployment metadata.

The owner confirmed real Google sign-in. Cancellation is covered by the real
local browser tests, but the owner did not report a production cancellation test.
The first sign-in attempt exposed a CSP block on Google's popup initialization script.
The fix permits `https://apis.google.com` in script and connection sources;
isolated Chrome reached the real Google identity chooser with no CSP violations
after the final deployment. The page now explains
blocked/closed popups and connection/configuration errors without exposing raw
exceptions. Password-reset delivery also needs an inbox check before claiming
it is verified.

## Runtime identity and staged deployment

The owner explicitly approved a dedicated Firebase service-account credential in
Neon's private environment. It is not stored in source, local `.env`, reports,
the browser or app. Identity:
`moviehub-account-cleanup@my-flutter-app-hezra-202-12dc9.iam.gserviceaccount.com`.
Custom role `movieHubAccountCleanup` grants database metadata, Firestore entity
get/list/create/update/delete, and Firebase Auth user get/delete. It does not
grant project administration or Auth user creation/update. The API and worker
share validated runtime configuration. `runtime-key-metadata.json` contains only
the key identifier for rotation; keep private material in the host environment.

The page's Firebase configuration was compared against registered web app
`1:609797109604:web:a31f4ccb96e9c978f12c71`. The exact API hostname is an authorized
Auth domain. Email/password and Google providers are enabled.

Run these commands from the repository root:

1. `node scripts/deploy_deletion_backend.cjs --disabled` initially creates the
   runtime key and deploys both flags false. Already completed; do not casually
   repeat this stage because it issues a new key.
2. `node scripts/check_deletion_production.cjs` verifies public access controls.
3. `node scripts/deploy_deletion_backend.cjs --enable-worker` enables only the
   scheduler. Omitted credential settings preserve the hosted credential.
4. `node scripts/check_deletion_scheduler.cjs` verifies aggregate scheduled runs.
5. Once Google verification succeeds, record that evidence in
   `production-readiness.json` and run
   `node scripts/deploy_deletion_backend.cjs --enable-deletion`. Completed.
6. Check the installed app with a disposable account and add the functioning
   public URL to Play Console.

Deployment requires passing emulator evidence for the exact bundle hashes and
rejects unrelated resource changes, deletions, branch changes and conflicts.
Raw CLI output is suppressed because it can contain private configuration.
Ordinary deployments default both flags false; use the staged rollout script.

The retry handler accepts only Neon-attested scheduled calls: Neon strips
client-supplied `X-Neon-*` headers, verified with a live forged request. It also
checks runtime, matching invocation ID and scheduled timestamp. Redesign this
trust boundary if moved to another host. See [Neon triggers](https://neon.com/docs/compute/functions/triggers/overview)
and [schedules](https://neon.com/docs/compute/functions/triggers/schedule).

## Behavior and data coverage

The app reauthenticates with email/password or Google and refreshes the ID token.
The server checks revocation, rejects anonymous users and requires `auth_time`
within five minutes. Refreshing an old token alone is insufficient. Only the
verified token determines the UID. The browser uses in-memory sign-in and sends
an ID token, never the password, to the Movie Hub backend. Cancel signs out.

A transaction creates `account_deletions/{uid}` before cleanup. Bounded queries
delete authored posts recursively, replies on other posts with atomic count
updates, likes with recomputed totals, reward sessions/receipts, reward accounts
and redemptions, and `users/{uid}` descendants. Cleanup removes reports submitted
by or targeting the user, anonymizes their reviewer identity in other reports,
deletes incoming blocks, and removes `forum_members/{uid}` descendants including
community acceptance and outgoing blocks. Firebase Auth deletion is last.

After server acceptance the app clears that user's local lists/history and signs
out. HTTP 200 means complete; 202 means a durable request is pending. A timeout
is uncertain and must not be reported as success. The worker resumes interrupted
jobs and purges completed fences after seven days. Pending jobs remain until
cleanup succeeds. Reward transactions, including signed ad callbacks, read the
same fence so late callbacks cannot recreate a wallet.

Deployed rules fence writes by deleting users and replies on their posts, deny
client access to private deletion/reward data, and fence report/block targets.
Preserve those controls and indexes, including `comments.uid` and `blocked.uid`
collection-group indexes. New client-writable collections need equivalent checks;
a deny rule cannot override another allow rule.

Device-only lists/history on other installations and downloaded files are not
remotely erased. Historical Analytics/Crashlytics records and backups follow
their providers' retention/deletion mechanisms; this flow does not erase those
datasets. Direct Auth deletion in Firebase Console bypasses cleanup; process a
durable cleanup job first.

## Verification and operations

- 36 backend tests pass: authentication, isolation, retries, rewards races,
  runtime credentials, worker authorization and hosted transport.
- Five integration tests pass with real local Auth/Firestore emulators, actual
  deployable API/worker bundles and Chrome. Coverage includes two-user isolation,
  descendants/counts, Auth-last ordering, interrupted recovery, wrong password,
  cancellation and confirmation.
- Five Flutter account-deletion service tests pass with the IDE Flutter SDK:
  complete/pending results, stale auth, malformed/failing responses and HTTPS.
- Forum rules passed 30 emulator/readiness tests separately.

The emulator launcher uses a demo project and isolated credentials. Logs redact
access tokens before writing. A Google application-default credential exposed
by an earlier emulator run was revoked with explicit approval; the separate
Firebase CLI login still works.

Worker logs contain aggregate counts without UIDs/credentials. Failed passes
return 503 with retry-after 300 and severity ERROR; jobs pending over one hour
also emit severity ERROR. These events are not an email/SMS subscription.
Operator notification configuration and delivery remain unverified. Monitor
schedule health and pending age using `check_deletion_scheduler.cjs`.

## Separate follow-up work

App Check, rate limiting and API usage alerts were reverted at the owner's
request. Content rights,
production ads/consent/reward callbacks, cloud My List and iOS configuration remain
separate tasks. Forum reporting, blocking and moderation are implemented and
have been exercised on the updated Android app.

References: [Play account deletion](https://support.google.com/googleplay/android-developer/answer/10144311),
[Firebase reauthentication](https://firebase.google.com/docs/auth/flutter/manage-users),
[Firestore deletion](https://firebase.google.com/docs/firestore/manage-data/delete-data),
[Firebase security checklist](https://firebase.google.com/support/guides/security-checklist).
