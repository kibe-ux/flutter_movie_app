# MovieHub production runbook

Maintained against repository configuration on 2026-11-05. Use this for routine
releases and incident recovery. Historical deployment IDs and audit counts are
evidence from a particular release, not a guarantee of current production state.

## Systems and responsibilities

| Component | Purpose | Configuration |
| --- | --- | --- |
| Flutter app | Browsing, account access, downloads and playback | `pubspec.lock`, root `.env`, native app configuration |
| Neon `moviehub` | Authenticated API, metadata proxy, rewards, deletion API/page | `backend/neon.ts`, scoped by `backend/neon.catalogue.ts` |
| Neon PostgreSQL | Shared public catalogue and API quota buckets | Backend `DATABASE_URL`; injected into the hosted function |
| Firebase Auth / Firestore | Identity, forum, reward wallets and deletion records | Runtime identity, deployed rules and indexes |
| Wambesha | Search and playback/download source discovery | Server-side `WAMBESHA_API_KEY` |
| TMDB | Browsing and descriptive metadata | Server-side `TMDB_API_KEY` |
| AdMob | Ads and signed reward callbacks | Publisher configuration and backend feature flags |
| Neon `accountcleanup` | Durable account-deletion retries | Separate function and `account-deletion-retries` schedule |

Neon project: `summer-shadow-58564268`. Branch: `br-empty-forest-b4htkwt9`.
Firebase project: `my-flutter-app-hezra-202-12dc9`.

API base:
`https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech`

Confirm these targets before release. Deployment 14 was last verified during the
security release; use `npm run neon:status` to discover the current deployment.
Assign a release owner and an incident responder with working Neon/Firebase
access. Record the responder's private contact details in the team's operations
channel, not in public source control.

## Configuration and secrets

Use [backend/.env.example](backend/.env.example) and [.env.example](.env.example)
for names and placeholders. Never replace placeholders in committed files with
real secrets. The deployment wrapper reads private `backend/.env`; process
environment values override matching file values. Configure CLI authentication
privately on the release machine.

| Setting | Location and requirement |
| --- | --- |
| `FIREBASE_PROJECT_ID` | Backend; required by deployment |
| `TMDB_API_KEY`, `WAMBESHA_API_KEY` | Backend only; both required by deployment |
| `DATABASE_URL` | Local backend for database checks; Neon injects the hosted connection |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Private hosted environment, or approved runtime credentials; required permissions must support Firestore/rewards/deletion |
| `JWT_SECRET` | Backend; needed only for legacy local-file signed downloads |
| `MOVIE_DOWNLOAD_API_BASE_URL` | Flutter asset; use the production HTTPS base, with no credentials |
| `ADMOB_USE_TEST_ADS` and ad unit IDs | Flutter/native settings; validate publisher IDs before enabling live ads |
| `ADMOB_REWARDS_ENABLED`, `ADMOB_REWARDED_UNIT_IDS` | Backend; enable acquisition only after SSV verification and wallet access work |
| `ACCOUNT_DELETION_ENABLED` | `moviehub`; deliberately preserve the intended release value |
| `ACCOUNT_DELETION_WORKER_ENABLED` | Worker and schedule configuration; managed by its rollout workflow |

**Feature flags must be deliberate.** `neon.ts` writes deletion/reward flags as
`false` when missing or not exactly `true`; missing rewarded unit IDs become
empty. A routine API deployment can therefore disable these API features even
when it leaves the worker untouched. Compare intended values with the privately
recorded production configuration before deployment. Omitted credential settings
preserve hosted values; simply deleting a local variable does not revoke a key.

Do not run `--disabled` from the deletion rollout as a routine release shortcut:
that stage provisions a runtime key. Follow the dedicated rollout guide for
worker changes and new credentials.

Shared defaults, all per fixed minute:

| Setting | Default | Scope |
| --- | --- | --- |
| `CATALOGUE_CLIENT_LIMIT` | 120 | Verified UID or guest installation |
| `CATALOGUE_UPSTREAM_LIMIT` | 600 | Actual TMDB requests across instances |
| `WAMBESHA_CLIENT_LIMIT` | 60 | Valid requests per verified UID, including cache hits |
| `WAMBESHA_SOURCE_LIMIT` | 8 | New source checks per UID |
| `WAMBESHA_UPSTREAM_LIMIT` | 120 | Actual Wambesha calls across instances |

Check provider account allowances before changing budgets. Guest installation
IDs can be reset; they are not an authentication boundary. The global provider
budget still applies. Fixed windows allow bursts across minute boundaries.

Wambesha additionally limits decoded provider responses to 1 MiB, provider
headers/body reads to 15 seconds, and new provider tasks (including quota checks)
to eight per API instance. Saturated instances return 503 with `Retry-After: 1`;
inspect concurrency/latency rather than increasing provider quotas to fix it.
Malformed or oversized provider responses return generic 502 errors and are not
cached. Source-cache payloads are capped per instance at 8 MiB and 128 LRU
entries. Expiry is at most five minutes (30 seconds for empty replies), shortened
to 30 seconds before the earliest supplied link expiry. Unknown-expiry links
still need actual delivery checks. These limits do not bound the entire process
heap or replace host-level request/connection controls.

## Release preflight

1. Identify the commit and confirm the release checkout contains only intended
   changes. The bundler reads working files, not a Git commit automatically.
2. Use Node 22 or newer locally; hosted bundles target Node 24. Use the Flutter
   SDK compatible with the release's committed `pubspec.yaml` and lockfile.
3. Run the following checks, stopping on any nonzero exit code. PowerShell does
   not automatically fail a script when a native command fails.

From the repository root:

```powershell
git status --short
git rev-parse HEAD
flutter analyze
flutter test
```

Then from `backend`:

```powershell
npm ci
npm test
npm audit --omit=dev
npm run db:check
npm run neon:build
```

Install development dependencies on the build machine: the bundler and deployment
CLI are development tools. `--omit=dev` above applies to the audit, not the install.
Review the full tooling audit separately; do not use `npm audit fix --force` to
silently replace the deployment CLI with an incompatible release.

For database/quota/storage changes, run the opt-in isolated integration check
from `backend`. It creates and drops its own test schema and requires a role
allowed to do so; prefer a designated test branch for routine development.

```powershell
$env:CATALOGUE_STORAGE_INTEGRATION = '1'
node --test test/catalogue_storage_integration_test.js
Remove-Item Env:CATALOGUE_STORAGE_INTEGRATION
```

Rules, deletion and moderation changes also need their actual emulator/browser
checks. Follow the linked rollout guides for emulator prerequisites and evidence;
they are not implied by the ordinary backend test suite.

Do not build or distribute an APK as part of an API-only release. Mobile releases
require separate approval of signing, Firebase fingerprints, publisher ad IDs,
supported-device checks and installed-app behavior. Preserve existing signing
identity so updates can retain local downloads.

## Routine API deployment

From `backend`:

```powershell
npm run catalogue:plan
```

Despite its name, this scopes the **entire `moviehub` API** deployment, including
Wambesha, rewards and the public deletion page, not just metadata caching.
Require the expected project/branch, zero conflicts, and changes limited to
`function:moviehub`. Stop on unrelated changes, deletes or target mismatches.

After reviewing the plan and private feature flags:

```powershell
npm run catalogue:deploy
npm run neon:status
```

The wrapper rebuilds the bundle, checks loaded private values are excluded, and
prints a sanitized deployment summary. Require a completed active deployment and
the expected URL. `catalogue:deploy` does not itself require a successful earlier
plan: running/reviewing the plan is an operator step. It also rebuilds from the
current files, so do not edit source or configuration between plan and deployment.

Do not substitute `npm run neon:deploy` casually: its full configuration also
declares `accountcleanup` and the deletion schedule. Firestore rules/indexes,
Firebase IAM, AdMob SSV settings and mobile binaries are separate deployments.

## Checks after deployment

From a PowerShell terminal, these checks discard response bodies and contain no
credentials. Check each status against the expectation below.

```powershell
$apiBase = 'https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech'
curl.exe --silent --show-error --output NUL --write-out "%{http_code}\n" "$apiBase/health"
curl.exe --silent --show-error --output NUL --write-out "%{http_code}\n" "$apiBase/api/wambesha/genres"
curl.exe --silent --show-error --output NUL --write-out "%{http_code}\n" --request POST "$apiBase/api/rewards/daily"
curl.exe --silent --show-error --output NUL --write-out "%{http_code}\n" "$apiBase/api/mobile/details"
curl.exe --silent --show-error --output NUL --write-out "%{http_code}\n" "$apiBase/api/films365/trending"
```

Expect `200`, `401`, `401`, `404`, `404`, in that order. Health proves process
availability, not database connectivity or authenticated feature readiness.

Check public metadata caching twice, with different installation IDs:

```powershell
$installation = [Guid]::NewGuid().ToString('N')
curl.exe --silent --show-error --dump-header - --output NUL --header "X-MovieHub-Installation: $installation" "$apiBase/api/catalogue/3/movie/popular?page=1"
$installation = [Guid]::NewGuid().ToString('N')
curl.exe --silent --show-error --dump-header - --output NUL --header "X-MovieHub-Installation: $installation" "$apiBase/api/catalogue/3/movie/popular?page=1"
```

Both should return 200; the second should normally report `X-MovieHub-Cache: HIT`
(or `COALESCED` during a concurrent fill). Investigate repeated cold misses or
unexpected stale responses. Do not paste authenticated requests into shared logs.

With a designated signed-in test account/device, verify search, rich details,
movie and episode sources, download/resume, playback and offline playback. Check
`GET /api/database/health` with that account. For rewards changes, claim the daily
bonus twice: the first eligible claim awards five coins, the second awards zero,
and the server wallet remains consistent. Check existing passes survive refresh.
Test actual ad rewards only through the approved publisher/SSV test procedure.

For deletion, use a disposable account and the dedicated checklist: deletion is
irreversible. Never delete an operator's real account as a smoke test. Confirm
pending deletion jobs are retried by the separately deployed worker.

## Monitoring and storage

Configure monitoring; the repository does not automatically provision an alerting
service. A useful starting point is to alert on repeated health failures, a
sustained API 5xx rate above 1%, provider-budget exhaustion, rising stale replies,
or deletion jobs that remain pending despite several five-minute worker cycles.
Tune windows against measured traffic rather than treating these as an SLA.

Track request count, latency, 401/429/5xx rates, provider usage and quota budgets,
catalogue hit/stale ratios, database storage, reward failures and pending deletion
age. Use structured request logs containing `requestId` for HTTP counts; count
catalogue `upstream-request` events for actual TMDB attempts and
`upstream-budget-rejected` for suppressed attempts. Do not double-count the
separate cache-result and request-log events. Wambesha needs provider-dashboard
usage or shared quota counters to measure actual outbound calls. Some rewards
routes are currently grouped as `/api/other` in request logs; add safe route
labels before relying on endpoint-specific alerts.

Read-only SQL after catalogue initialization:

```sql
SELECT pg_database_size(current_database()) AS database_bytes;
SELECT COALESCE(SUM(payload_bytes), 0) AS live_catalogue_bytes,
       COUNT(*) AS cache_keys
FROM moviehub_catalogue_cache;
SELECT bucket_key, window_start, hits
FROM moviehub_catalogue_limits
WHERE bucket_key IN ('tmdb:upstream', 'wambesha:upstream');
```

Buckets describe only their recorded minute window, not lifetime usage. The
catalogue cap is 100,000,000 bytes of live JSON responses, **not** total database
size. Indexes, quota rows, other tables and allocated/dead space still count
toward the hosting allowance. For the reported 1 GB allowance, start storage
alerts below the ceiling (for example 70% warning and 85% urgent), then confirm
the account's actual storage definition in Neon. Automatic cache cleanup does
not guarantee the whole database stays below 1 GB. Do not delete reward wallets
or deletion fences to free space.

## Incident response

| Symptom | First checks and response |
| --- | --- |
| Health unavailable | Check active deployment, hosting status and sanitized logs; consider a reviewed code rollback. |
| Health works, catalogue returns 503 | Check PostgreSQL connectivity, quota window, provider status and stale-cache availability. Database failure intentionally stops unrestricted requests. |
| Wambesha 429 or 503 | Respect `Retry-After`; check per-user/global budgets and database access. Raise budgets only within the provider allowance. |
| Firebase-marked 401 | Reauthenticate the test account; inspect project/runtime configuration and revocation. Do not replace provider keys to fix a Firebase session. |
| Provider 502/504 | Check provider availability and backend key validity; do not log provider bodies or signed links or add automatic retry storms. |
| Rewards unavailable | Check runtime Firestore permissions, SSV configuration, ad units and acquisition flags. Disabling ad acquisition does not disable daily claims or invalidate already-issued callbacks. |
| Deletion pending | Inspect worker scheduling, runtime identity and pending-job age using its rollout workflow. Preserve fences and jobs. |
| Database nearing allowance | Measure all relations and quota growth; review automatic cleanup and capacity. Avoid destructive live-table cleanup without a recovery plan. |

Record incident start/end in UTC, affected features, release/deployment IDs,
sanitized request IDs and changes made. Preserve evidence without tokens, search
queries, private user data or delivery URLs. Keep users informed through the
normal support channel; this runbook does not send messages automatically.

## Code rollback and data recovery

1. Select a previously tested commit that remains compatible with installed apps,
   current data and required security controls. `9b616c3` is the security baseline,
   not an instruction to roll every future release back to it. Review any older
   candidate for removed HTTPS, daily-reward, quota or Wambesha resource protections.
2. Use a separate clean checkout/worktree; preserve current operator edits.
   Install that commit's locked dependencies with `npm ci` and provision current
   secrets privately. Keep current safe feature flags and credentials; do not
   restore retired keys from an old environment snapshot.
3. Run preflight and the scoped plan/deploy workflow above from the recovery
   checkout. The deployment helper has hardcoded project/branch targets: verify
   them even when using historical code. If that commit lacks a scoped helper,
   prepare a reviewed scoped configuration before deploying.
4. Expect a new deployment ID for the rollback. Repeat live checks, record both
   deployment IDs and confirm recovery before closing the incident.

A code rollback does not undo Firestore writes, redeemed passes, deleted accounts
or database migrations, and does not downgrade installed mobile apps. Do not
restore old reward balances automatically: that can resurrect spent credits or
replay payments. Restoring snapshots may also resurrect deleted personal data;
reconcile deletion records before returning restored data to service.

Before any release requiring data migration, record the available Neon restore
window and Firebase backup/export policy, recovery access, recovery-time objective
and acceptable data-loss window. Do not assume backups, retention or restore
features are enabled. Store backups encrypted with restricted access and verify
restoration in an isolated environment. Public catalogue data is disposable;
reward ledgers, receipts, moderation and deletion state require deliberate recovery.

## Credential rotation

Identify the credential and affected systems; issue the replacement through the
provider's private administration workflow. Update only the relevant private
runtime setting, deploy the affected function(s), and verify access before
revoking the old credential when overlap is safe. If a credential is actively
compromised, prioritize revocation even if that temporarily disables a feature.
Runtime Firebase credentials are shared by the API and cleanup worker; rotate
both and verify actual scheduled work before retiring the old key. Preserve IAM
scope. Rotate the database password through its private connection configuration;
never paste a connection string into a command or incident report.

Removing a local variable does not remove the hosted key. Use the host's explicit
removal mechanism and verify the key is absent by name. Rotating the legacy
`JWT_SECRET` invalidates existing local-file signed URLs. Values shipped in an
old APK remain extractable; revoke exposed provider credentials server-side.

## Release record and remaining work

Record: operator, UTC time, source commit, Node/Flutter versions, test/audit
results, reviewed target and flag values (no secrets), previous/new deployment
IDs, smoke-test evidence, mobile version if applicable, and rollback candidate.
Keep operational evidence in restricted storage; local `reports/` is ignored and
is not a shared durable release record. Log any risk accepted for this release.

App Check registration/enforcement, infrastructure abuse controls, developer-tool
advisories, unknown-expiry delivery validity and hosted load/soak testing remain
follow-ups. Read the [security guide](SECURITY_GUIDE.md) before claiming readiness.

Related guides:

- [Backend configuration and endpoints](backend/README.md)
- [Load-test commands, scope and sizing](docs/LOAD_TESTING.md)
- [Local load-test results, 5 November 2026](docs/load-testing-results-2026-11-05.md)
- [Catalogue cache and storage limits](backend/CATALOGUE_CACHE.md)
- [Account deletion rollout](docs/account-deletion-rollout.md)
- [Forum rules and moderation rollout](docs/forum-security-rollout.md)
- [Historical account/forum rollback](docs/account-forum-rollback.md)

Historical rollout reports describe their deployment date. Compare them with the
current configuration; they do not override later releases or prove live flags.
