# Reducing provider usage

Browsing and search use the TMDB catalogue proxy and its existing PostgreSQL
cache. Download preparation uses Wambesha after the interstitial transition.
Interstitial availability, cooldown and ad-free access can let the transition
proceed without an ad; this is not a rewarded-ad completion gate.

## Reporting

The backend emits JSON events with `component: "wambesha-usage"` for upstream
attempts, response status, local cache hits, coalesced calls, shared-cache
outcomes, source errors and `verification_spent`. Missing verification metadata
is unknown, never assumed to be zero. Counts are operational observations,
not an invoice: interrupted requests or incomplete log exports can undercount.
No signed links, provider keys, title IDs or user identifiers are logged.

Export raw JSON log messages from the host and summarize them in PowerShell:

```powershell
Get-Content -LiteralPath .\server-log.jsonl | node .\scripts\summarize_wambesha_usage.js
```

Keep logs for the billing period; this command does not query Wambesha or create
charges. Reconcile totals with the provider console. Host-specific log wrappers
must be removed before piping lines into the script.

## Shared source cache

`WAMBESHA_SHARED_SOURCES=false` remains the default. Local per-user caching and
in-flight coalescing continue to work. Language and provider credential are part
of the identity so variants and key rotations cannot reuse the wrong result.

The opt-in implementation uses the existing bounded PostgreSQL catalogue store
and atomic leases to coalesce requests across instances and users. It never
serves expired or stale source responses, keeps empty results for 30 seconds,
and caches signed responses for at most five minutes, ending 30 seconds before
the earliest declared expiry. Responses with missing expiry are not persisted.
Store failures fail closed; failed refreshes impose a 15-second backoff. There
are no automatic upstream retries in source resolution.

Before enabling it, obtain confirmation or test authorized links across users,
devices and server egress addresses, and confirm the actual `expires_at` field
and reuse conditions. Public documentation did not establish those conditions.

Live metadata check on November 10, 2026: one authenticated source request
returned HTTP 200 and `verification_spent: true`. Both `playback_holding` and
`file_holding` entries supplied ISO-8601 `expires_at` values. Their signed URLs
included `exp` and `sig` parameters. This confirms the expiry field used by the
cache implementation, but does not establish a fixed link lifetime or reuse
across users, networks or server egress addresses. No signed URLs or credentials
were saved, and no file download was attempted. Cross-user caching stays off.

Then set `WAMBESHA_SHARED_SOURCES=true` in the private backend environment and
redeploy. This setting is passed through the Neon deployment configuration.
Revert to false and clear stored entries if reuse is unreliable.

Cache records use the `wambesha-source:v1:` namespace. Remove them when the
provider licence ends or when invalidating cached links:

```sql
DELETE FROM moviehub_catalogue_cache
WHERE cache_key LIKE 'wambesha-source:v1:%';
```

This removes only the source-cache namespace, not public TMDB catalogue data.
Coordinate invalidation with stopping/restarting API instances to clear local
memory too. Never commit or expose the database credentials or cache bodies.

## Spending controls and final verification

Disable verification overage or set a hard ceiling in Wambesha's billing
console. This repository does not change your subscription or billing settings.
The existing per-user and global minute limits remain in force; they do not
replace a provider monthly spending cap.

Last step: on Android, check movie and episode downloads, ad dismissal,
unavailable ads, rapid taps, source failures, and unchanged Cinema Rewards coin
behavior. Confirm logs show no Wambesha requests for browsing and searches.
No real-device or real-provider verification has been performed by these tests.
