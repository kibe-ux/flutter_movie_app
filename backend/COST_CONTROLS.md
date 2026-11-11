# Wambesha cost controls

Defaults target Free. These local safety budgets do not mirror provider billing.
Keep provider overage disabled in the developer console.

| Setting | Free default | Starter suggestion after upgrading |
| --- | ---: | ---: |
| `WAMBESHA_MONTHLY_CALL_BUDGET` | 45000 | 450000 |
| `WAMBESHA_MONTHLY_SOURCE_BUDGET` | 900 | 9000 |
| `WAMBESHA_DAILY_CALL_BUDGET` | 9000 | 45000 |
| `WAMBESHA_DAILY_SOURCE_BUDGET` | 180 | 900 |
| `WAMBESHA_VERIFICATION_RESET_DAY` | 1 | Dashboard billing day (UTC) |

Calls reset on the first UTC day of each calendar month; source reservations
reset on the configured billing day (clamped to the last day of short months).
Daily budgets reset at midnight UTC. Zero blocks requests for that meter.
Invalid environment settings fail startup rather than disabling protection.

Before first deployment, fill the four `WAMBESHA_INITIAL_*_USED` settings with
dashboard usage already spent in each window. These seed the account row once.
Changing them later never overwrites existing counts. Include a margin if usage
continues elsewhere during deployment.

Every instance/key for the same provider account must share one database and
`WAMBESHA_BUDGET_SCOPE`. Keep that scope stable across restarts, key rotation and
upgrades. A new database/scope starts a new ledger. Other keys/tools used outside
this backend are invisible locally: reconcile with the provider dashboard.

## Atomic reservations

Before each actual Wambesha fetch, reserve one API call and, for `/sources`, one
possible verification. A single conditional PostgreSQL UPDATE checks all four
budgets together. Old requests cannot move periods backwards at midnight.
Minute-rate cleanup never deletes durable budget/usage records.

Reservations are NOT refunded after errors, timeouts, empty responses or reported
zero verifications. This conservative cap may stop earlier than the provider
allowance. Actual reported verification spends are counted separately.

Both `/api/wambesha` and Wambesha catalogue calls in `/api/catalogue/3` are covered.
Database failure blocks new upstream calls. Exhaustion returns 503/Retry-After;
valid cached results remain usable. Source exhaustion alone allows metadata
requests while the API-call budget remains available.

## Cache lifetimes

* Public lookups and genres: 24 hours.
* Public title records/batches: six hours.
* Episode pages: one hour, keyed by season, cursor and language.
* Source replies: at most five minutes; all signed expiries shorten this to the
  earliest expiry minus 30 seconds. Empty responses last 30 seconds.

PostgreSQL leases coalesce metadata misses across instances. Keys include the
credential hash and sorted query. Failed/malformed answers are not published;
delivery fields are stripped from long-lived metadata.

`WAMBESHA_PERSISTENT_SOURCES=true` reuses known-expiry links for the SAME verified
user across instances. Unknown-expiry links stay local. Cross-user reuse remains
disabled with `WAMBESHA_SHARED_SOURCES=false`: the public documentation does not
establish that every host permits cross-user/cross-egress reuse. Enable only
after provider confirmation and a real delivery check.

Metadata rendering and More info trailers do not fetch sources. Copying a link
already in the download sheet makes no provider call.

## Usage reporting

Run `npm run wambesha:usage` from backend with the deployment's DATABASE_URL,
budget settings and scope. The JSON includes limits, UTC periods, reservations,
remaining quotas and monthly aggregate events. No public admin endpoint is added.
No credentials, user IDs or signed links are stored in the usage records.

Events track source hits/coalescing, persistent hits, metadata hits, rejections,
source errors, reported verifications and unknown verification responses.
Reporting failures log `reporting-error` without refunding reservations.
Event reporting buckets are calendar months; source quota periods are separate.

`node scripts/summarize_wambesha_usage.js` also summarizes exported JSON logs on
stdin, including metadata hits, quota rejections and report failures.

The guard caps request attempts, not a dollar invoice or delivery traffic.
Provider fair-use/overage rules and other account usage still require the
provider-side spending cap and dashboard checks.

References checked November 11, 2026: [pricing](https://www.wambesha.com/en/pricing),
[terms](https://www.wambesha.com/en/terms),
[public OpenAPI](https://api.wambesha.com/api/v1/docs/openapi.json).

Deploy the backend to activate. Local tests do not migrate production tables
or deploy changes. Confirm dashboard usage/limits before that deployment.
