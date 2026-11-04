# MovieHub security controls

This document records repository controls and known gaps. It is not a security
certification or an independent audit of the deployed configuration.

## Trust and credentials

- The app is an untrusted client. Provider keys, database passwords and Firebase
  service-account credentials belong only in the backend private environment.
- Private routes verify Firebase ID tokens, including revocation. Rewards reject
  anonymous accounts. Firebase client configuration is not a server secret.
- Wambesha supplies search and playback/download sources. TMDB metadata uses the
  backend catalogue proxy. Retired provider routes return 404.
- A Firebase identity does not prove the caller is an unmodified application.

Never put provider keys in Flutter assets, source constants, secure storage or
`--dart-define`: values shipped to a device can be extracted. Obtain ID tokens
from Firebase Auth when needed; do not copy them into preferences. Do not log
authorization headers, signed URLs, credential values or raw sensitive exceptions.
Keep environment and service-account files out of Git. Rotate any key exposed in
an older APK; removing it from current source cannot invalidate existing copies.

## Transport

Android main/release configuration disables cleartext traffic. Authenticated
backend clients validate URLs before sending credentials: HTTP is rejected
outside debug builds, as are embedded credentials, query strings and fragments.
Debug HTTP is restricted to explicit local hosts in Dart and the Android debug
network configuration. Account deletion requires HTTPS. iOS has no arbitrary-load
exception configured. Delivery source URLs must use HTTPS.

Installed applications receive client security changes only after an update.
Backend deployment alone cannot change the code in an installed APK.

## API abuse controls

TMDB uses allowlisted routes and parameters, a fixed provider host, rejected
redirects, bounded responses and timeouts, shared PostgreSQL caching, and shared
rate limits. Defaults are 120 requests per identity/minute and 600 actual provider
requests globally/minute. Guest installation IDs are resettable identifiers, not
authenticated identities. See [cache limits](backend/CATALOGUE_CACHE.md).

Wambesha authenticates requests and validates allowed routes and parameters.
Atomic PostgreSQL rate buckets apply across server instances:

| Setting | Default per minute | Scope |
| --- | --- | --- |
| `WAMBESHA_CLIENT_LIMIT` | 60 | Valid requests per verified UID, including cache hits |
| `WAMBESHA_SOURCE_LIMIT` | 8 | New source checks per UID |
| `WAMBESHA_UPSTREAM_LIMIT` | 120 | Actual provider calls across users and endpoints |

Source-cache hits and local in-flight followers avoid another source/upstream
check, but count toward the client limit. Failed provider attempts consume quota.
Limits use fixed minute windows; bursts across a boundary remain possible.
Client limits return 429. The global budget and quota-store outages return 503.
Both include `Retry-After`. Database failure never enables unrestricted access.
Source coalescing is per process, not distributed. Configure budgets for the
actual provider allowance before increasing them.

Wambesha provider bodies are streamed with a 1 MiB decoded-byte limit, including
responses with compressed, missing or misleading length headers. The 15-second
deadline covers provider headers and body reads. Malformed/non-object JSON and
invalid source envelopes are rejected, never cached, and returned as generic
errors. Unconsumed error/oversized bodies are cancelled without waiting on an
untrusted cancellation promise.

Each API instance admits at most eight new provider tasks, including their quota
checks; local source followers reuse an existing task. Excess new work receives
503 and `Retry-After: 1`. The per-user source cache uses LRU eviction, at most
128 entries and 8 MiB of encoded JSON buffers. These are payload/entry bounds,
not total Node heap limits. Expired bodies are pruned on cache access and
insertion; there is no persistent signed-link cache. Entries expire after at most
five minutes (30 seconds for empty sources), or earlier at the earliest supplied
link expiry minus a 30-second safety margin. Invalid expiry, near-expired URLs
and URLs containing credentials are discarded.

The hosted HTTP adapter caps bodies at 1 MiB. Firebase verification precedes
Wambesha quota checks. Infrastructure-level connection limits, request limits
and DDoS protection are still needed for hostile unauthenticated traffic.

## Rewards and daily check-in

Ad rewards require a verified Google SSV signature, a matching server-issued
session, an allowed ad unit, server-time checks, and transaction receipts that
prevent double credit. Client ad callbacks never add spendable coins. Redemption
checks and subtracts the server wallet atomically with idempotency receipts.

`POST /api/rewards/daily` grants five coins once per signed-in, non-anonymous
account per UTC day. The server supplies the day and amount. A Firestore
transaction serializes claims across devices and retries; account-deletion fences
prevent claims. Daily claims remain available when ad acquisition is disabled.
Flutter displays the returned server wallet. Device dates and preferences cannot
grant credits. Old local-only bonuses are not imported as trusted funds.

## Firestore and account deletion

Repository rules deny access to unspecified collections. Forum writes validate
membership, ownership and fields; moderation requires a server-managed claim.
Wallets, receipts and deletion records are backend owned. Forum posts are publicly
readable by design. Blocking limits interactions, not access to public posts.

Account deletion requires recent authentication and a durable deletion fence.
See [rollout instructions](docs/account-deletion-rollout.md). A rules file in Git
does not prove it is deployed. Verify the active project and deployed rules
separately. Admin credentials bypass client rules: use a dedicated runtime
identity with minimum required IAM permissions.

## Outstanding work

- Register platform providers for Firebase App Check, add client tokens and backend
  verification, and test real devices before enforcement. App Check is not yet
  implemented. Existing installed versions need a rollout plan.
- Verify deployed Firestore rules and runtime IAM. Configure host-level abuse
  controls, monitoring and alerts. One reward per account does not prevent
  multi-account abuse; forum and account-creation abuse also need monitoring.
- Wambesha URLs without expiry metadata cannot prove continued validity despite
  the bounded five-minute backend cache and 30-second Flutter cache. Continue
  checking actual delivery failures and provider validity/expiry guarantees.
- Review dependency advisories and test supported devices, hostile inputs and
  proxy/network failures before publication.

Run Flutter analysis/tests, backend regressions, and isolated database/rules
integration checks. Passing tests is not a penetration test or a capacity test
for 50,000 concurrent users. Certificate pinning, universal request signing and
an independent production security audit are not claimed.

## Dependency installs

Use `npm ci` from `backend` to reproduce the checked-in lockfile. Generated
`node_modules` files are not source-controlled. The `qs` and `rimraf` overrides
select patched query parsing and cleanup dependencies; the runtime requires
Node 22 or newer. Audit production dependencies separately from developer tools
and retest backend bundles after dependency changes. A clean production audit
does not imply that developer tooling or mobile dependencies have been audited.

The 2026-11-05 backend audit reports zero production dependency advisories.
Developer tooling still reports seven advisories (one low and six moderate).
Those require separate compatible tooling upgrades; do not apply an automatic
forced CLI downgrade to hide them. Recheck advisories for each release.
