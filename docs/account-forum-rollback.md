# Account deletion and forum retained

The owner requested reverting the recent API-security additions while retaining
account deletion and the forum. The rollback is deployed to the existing Neon
project/branch: API `moviehub` deployment 9 and `accountcleanup` deployment 7.

## Removed

- Flutter App Check dependency, activation and outbound attestation headers.
- Backend App Check validation and distributed API rate-limit middleware.
- API usage maintenance/metrics publishing from the scheduled worker.
- Security-specific source files, tests, configuration and privacy statements.
- Hosted security environment settings, the three unused alert policies, their
  unused email notification channel, five custom metric descriptors and the
  unused metrics-only IAM role.
- Only the dedicated `moviehub_security` PostgreSQL schema, containing its own
  rate windows, daily counts and consume function. RESTRICT prevented cascading
  deletion into another feature's database objects.

App Check provider metadata remains registered in Firebase but unused by the
app/backend; service enforcement was never enabled during this rollout. Existing
Firebase app registrations are required by the retained features and were kept.
Billing was not changed.

## Retained

- In-app reauthentication and complete account-data cleanup, Auth deletion last.
- External `/delete-account` page with working Google verification.
- Durable jobs/fences and the five-minute account-deletion retry schedule.
- Dedicated Firebase runtime credential and minimal cleanup permissions.
- Forum reporting, blocking, moderator review/removal and community terms.
- Deployed Firestore rules/indexes required by deletion and forum moderation.

## Verification

- All 36 retained backend tests pass with one test worker. The first parallel
  run exhausted Windows memory; the sequential rerun passed.
- All 20 Flutter forum UI/service and account-deletion service tests pass.
- All five real Firebase emulator/browser integration tests pass for the exact
  deployed replacement bundles.
- A newly created disposable production account made 31 invalid-method search
  requests. All received method validation (405), none received rate limiting
  (429), and no App Check response header remained. No provider calls were made.
- The same test account was then deleted through the real account-deletion
  endpoint, and its old token no longer found a login. No existing user was
  used or deleted by this check.
- Hosted metadata confirms security settings are absent and the API/worker
  retain their account-cleanup credential.
- The retained five-minute retry worker ran successfully at 13:40:05 Nairobi
  after removal of the rate-limit schema. Public API health, enabled deletion
  page, unauthenticated deletion rejection and forged-worker rejection pass.

The updated debug APK is rebuilt at
`build/app/outputs/flutter-apk/app-debug.apk`. The first build hit a Windows
resource limit during D8 packaging. Retrying with a smaller heap and CPU limits
for all Java workers succeeded; no unrelated background process was stopped.
APK inspection confirms account deletion and forum safety are included and the
App Check service/Flutter package are absent. Phone installation/testing was
deferred by the owner earlier; this rollback does not claim a device test.
Evidence is under `reports/account-forum-rollback/` and the historical security
resource cleanup record is `reports/api-security/rollback.json`.
