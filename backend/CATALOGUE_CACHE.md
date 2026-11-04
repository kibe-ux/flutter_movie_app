# Shared movie catalogue

The Flutter app requests public movie/TV lists, discovery, search, metadata,
credits, trailers, providers and seasons through `GET /api/catalogue/3/...`.
The response shape remains TMDB-compatible. Image URLs still use TMDB's image
CDN. Playback/download URL verification keeps its separate authorization and
expiry rules; this cache does not store those links.

## Activation

1. Configure `TMDB_API_KEY` in the backend's private environment. The local
   credential has been moved from the Flutter `.env` to `backend/.env`.
   Never put a provider key in Flutter assets or `--dart-define` arguments.
2. Configure `DATABASE_URL` on the backend (Neon injects it for the deployed
   function). On first catalogue use, the database role must be able to create
   `moviehub_catalogue_cache` and `moviehub_catalogue_limits` in its current
   schema. Later requests use parameterized queries against those tables.
3. Run `npm test` and `npm run neon:build` from `backend`.
4. Deploy the backend before releasing the updated app. The existing
   `npm run catalogue:plan` / `npm run catalogue:deploy` commands update only
   `moviehub`, including the private credential and limits declared in
   `neon.ts`. Cleanup functions and schedules are excluded. No deployment is performed just
   by editing these files or running the build command.
5. Build the app with `MOVIE_DOWNLOAD_API_BASE_URL` pointing at that backend.
   There is deliberately no fallback to direct provider calls.
6. Smoke-test Home, Explore, guest browsing, a metadata page and TV seasons.
   Then verify repeated requests from different app installations report
   `X-MovieHub-Cache: HIT` or `COALESCED` after the first `MISS`.

An old server without this endpoint returns 404; deploy the server first.
Existing installed APKs retain their previous bundled settings until updated.

## Behaviour

- A provider response is fresh for 15 minutes. It is shared across users and
  across server instances through PostgreSQL. Each local hot cache is limited
  to 128 pages and 16 MiB of encoded response content.
- Canonical keys include the endpoint, page, language, filters and search text.
  Signed-in identity and guest installation IDs are never part of a shared
  public-response key.
- PostgreSQL upserts acquire a 60-second lease before a cold fetch. Each
  process also shares in-flight promises. Followers wait up to 20 seconds or
  reuse a still-valid stale response; an active lease never causes another
  provider call. An abandoned lease can be acquired after it expires.
- Provider requests have a 15-second timeout and a 1 MiB response limit.
  Errors and invalid responses are not saved as successful pages. A shared
  15-second failure cooldown avoids repeating a failing provider request.
- Previously successful responses can be served for up to another hour after
  freshness expires when the provider is unavailable or another instance is
  refreshing. Stale replies carry a `Warning` header. Older data is rejected.
- Pull-to-refresh bypasses the app cache, **not** the shared server TTL or
  upstream budget. Clients cannot force provider refreshes or arbitrary URLs.
- The persistent response-data budget is **100,000,000 bytes (100 MB)**.
  Every publish takes a shared PostgreSQL transaction lock, saves the response
  and evicts older payloads before committing. Concurrent instances share this
  same budget. Oversized responses are not persisted. Clearing an older payload
  preserves any active refresh lease for that key.
- The accounting uses the UTF-8 byte length of JSONB response text, backfills
  existing cached pages on migration, and also runs during periodic cleanup.
  This limits live response data, not the whole database: indexes, rate-limit
  rows, other application tables, and PostgreSQL's allocated/dead space also
  count toward the hosting allowance. Deleted payload space is available for
  database reuse; allocated table size need not immediately shrink.
- Persistent cache cleanup keeps about 2,000 recent inactive keys, removes
  expired rate buckets, and preserves active leases. Maintenance runs at most
  once per minute per instance. Guest browsing never needs a shared anonymous
  Firebase account.

## Limits and monitoring

The defaults, shared across instances, are:

| Setting | Default | Applies to |
| --- | --- | --- |
| `CATALOGUE_CLIENT_LIMIT` | 120/minute | Each verified Firebase UID, or guest installation ID; includes cache hits |
| `CATALOGUE_UPSTREAM_LIMIT` | 600/minute | All actual TMDB requests combined, including failed requests |

Client limits return HTTP 429 and `Retry-After`. Provider-budget exhaustion,
database outages and cold-cache provider failures return HTTP 503 with a retry
hint. The app does not automatically retry these failures. Database failure
does not enable an unrestricted direct-provider fallback.

Signed-in UIDs come only from Firebase token verification. Guest installation
IDs are convenience limits, not authenticated identities: resetting one does
not bypass the global provider budget. Add hosting/WAF traffic limits for
hostile unauthenticated traffic and load-test database/API capacity separately.

Requests only support a finite list of read-only TMDB routes and validated
parameters. The provider host is fixed and redirects are rejected. Keys,
tokens, request URLs, search terms and user IDs are excluded from catalogue
logs. Logs contain the endpoint, status and HIT/MISS/COALESCED/STALE result.
Count `upstream-request` events for actual provider attempts (including failed
attempts), and `upstream-budget-rejected` events for suppressed requests.

For 50,000 users, first adjust the provider budget to your actual provider
quota, then measure peak concurrency, cache-hit rate, provider calls/minute,
429/503 counts, latency and Neon database usage. User count alone does not
establish a capacity guarantee. These changes have automated tests, not a
50,000-concurrent-user production load test.
