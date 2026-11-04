# Movie Download Backend

Shared public catalogue caching, provider limits, and app migration are described
in [CATALOGUE_CACHE.md](CATALOGUE_CACHE.md).

## Wambesha search, playback and downloads

Set `WAMBESHA_API_KEY` in `backend/.env` for local development. The key stays
server-side; `neon.ts` supplies it through the moviehub function's private
environment during deployment. Never add it to Flutter's `.env` asset.

Flutter search uses these Firebase-authenticated GET routes:

- `/api/wambesha/search?q=Arrival`
- `/api/wambesha/titles?ids=mv_EXAMPLE,sr_EXAMPLE`
- `/api/wambesha/titles/:titleRef`
- `/api/wambesha/genres`
- `/api/wambesha/lookup?tmdb_id=329865`
- `/api/wambesha/titles/:titleRef/episodes?season=1&limit=50`
- `/api/wambesha/titles/:titleRef/sources`

Search fetches full records in a batch to map Wambesha IDs to TMDB IDs. Only
movies and series with a positive TMDB ID appear, since existing details,
bookmarks and downloads require that identity. Opening a result fetches its
canonical TMDB details. Movie/episode downloads now select Wambesha `file_holding`
URLs; Watch now/Watch episode select `playback_holding` URLs. The older
`MovieDownloadService.requestSignedDownloadUrl` also resolves Wambesha sources
instead of posting to `/api/download/request`. It accepts Wambesha movie IDs or
numeric TMDB movie IDs; legacy local-file IDs are not equivalent identifiers.
The quality argument is retained for caller compatibility, but the provider
does not document a quality selector for this endpoint.

Delivery sources can contain only `kind`, `url` and `host`; `expires_at` is
optional. Flutter accepts HTTPS delivery URLs without expiry metadata and keeps
its normal 30-second source cache. When an expiry is supplied, it must be valid
and more than 30 seconds in the future. Use the complete URL returned by the
API; a documentation URL ending in `...` is only a placeholder.

Source requests occur only on explicit play/download actions, never per search
tile or page render. Each process coalesces pending checks and reuses answers
on each Firebase UID and title. The Flutter cache lasts up to 30 seconds and
requires signed links to have more than 30 seconds remaining. The backend
currently retains nonempty source replies for five minutes and empty replies for
30 seconds; the app still checks supplied link expiry before using a source.
PostgreSQL shares limits across instances: 60 valid requests per UID/minute,
eight new source checks per UID/minute, and 120 actual provider calls globally
per minute. Configure WAMBESHA_CLIENT_LIMIT, WAMBESHA_SOURCE_LIMIT and
WAMBESHA_UPSTREAM_LIMIT. Cache hits and local followers avoid new source/provider
checks; they still count as client requests. Client limits return 429; global
budget exhaustion and database failures return 503. Both include Retry-After.
Failed upstream requests are not automatically retried or cached. API errors
are generic; source URLs, response bodies and credentials are not logged.
Torrent listings and evidence are removed from client responses; `form=uri`
and arbitrary source query parameters are rejected.

Episode lookup matches season AND episode, following episode cursors before
spending a verification on that episode. A missing file/playback source shows
an availability message; it does not fall back to the other kind or another provider.
Player Retry requests sources again (subject to the backend's short cache).
The retired FILMS365 proxy routes return 404. Descriptive details now use the
shared TMDB catalogue proxy; Wambesha supplies playback/download sources.
Account/key-management endpoints are not exposed. Provider
401/403 responses become 502; only Firebase 401 responses refresh the app token.

Deploy the backend before running the updated app against the hosted URL.
Restart the local Node process after changing local environment settings.
Focused checks: `node --test test/wambesha_test.js test/retired_provider_routes_test.js`
from `backend`, plus Flutter's `test/services/wambesha_api_service_test.dart`
and `test/services/wambesha_sources_test.dart`, `test/screens/search_screen_test.dart`,
`test/screens/video_player_screen_test.dart`, and
`test/screens/tv_seasons_section_test.dart` using the IDE Flutter SDK.

Account deletion is implemented behind `ACCOUNT_DELETION_ENABLED=false` by default.
See [the required rollout and verification steps](../docs/account-deletion-rollout.md)
before enabling the endpoint or submitting its public deletion URL to Google Play.
The deployed Neon retry function is `accountcleanup`, scheduled every five
minutes. Use the staged rollout script from the repository root; ordinary
deployments default both deletion flags to false.

## Setup

1. Run `npm ci` from `backend` using Node 22 or newer. Commit dependency updates
   through `package.json` and `package-lock.json`; do not commit `node_modules`.
2. Copy `backend/.env.example` to `backend/.env` and configure:
   - `FIREBASE_PROJECT_ID`
   - `WAMBESHA_API_KEY` for search and playback/download source verification
   - `TMDB_API_KEY` for public metadata
   - `DATABASE_URL` for the shared catalogue cache
   - `JWT_SECRET` only if using the legacy local-file download endpoints
   - `PORT` optionally (default `3000`)
3. Configure Firebase application-default credentials, or provide
   `FIREBASE_SERVICE_ACCOUNT_JSON` through the hosting platform's private
   environment. Never commit credentials or bundle them in Flutter assets.
   Both functions share `firebase_runtime.js`; malformed and cross-project
   credentials fail closed. Omitted credential settings preserve the hosted value.
4. Run `npm start`. The optional legacy local-file catalogue lists supported
   movie files placed in `backend/movies/`; deployment does not upload PC files.

## Hosted download API on Neon

The current `moviehub` function is on branch `br-empty-forest-b4htkwt9`
in project `summer-shadow-58564268`:

`https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech`

Flutter uses `MOVIE_DOWNLOAD_API_BASE_URL` to reach this backend. Installed
apps receive changed bundled settings only when updated.

From `backend`, use:

- `npm test` to check the API behavior.
- `npm run neon:build` to build backend bundles and check private settings are excluded.
- `npm run catalogue:plan` to preview changes to `moviehub` only.
- `npm run catalogue:deploy` to update `moviehub` without changing cleanup jobs.
- `npm run neon:status` to print the public URL and deployment status.

`neon.ts` declares both functions; `neon.catalogue.ts` scopes deployment to
`moviehub`. The `functions/moviehub/index.mjs` entry adapts Express through
`neon_http.js`. Provider keys stay server-side, and Neon injects the database
connection. Movie files are transferred directly from the Wambesha delivery URL
to the phone. Shared metadata caching has a 100 MB response-data budget; see
[cache behavior and limits](CATALOGUE_CACHE.md).

## Daily check-in

POST /api/rewards/daily requires a verified, non-anonymous Firebase account.
It atomically adds five coins once per account per UTC day to the server wallet,
independently of the ad-acquisition flag. Concurrent devices and retries cannot
multiply the award. Client amounts, dates and local preferences are not trusted.
The response contains the wallet and awardedCoins (five or zero). Deleted or
deleting accounts cannot claim.

## Cinema Rewards activation

The rewards wallet uses Firestore through Firebase Admin, independently of the
Neon PostgreSQL connection. The deployed function needs application-default
credentials with access to the Firebase project's Firestore database. Token
verification alone does not prove that Firestore access is configured.

Deploy the current backend source to expose `/api/rewards/wallet`, `/session`,
`/cancel`, `/redeem`, and `/ssv` under `/api/rewards`. Before enabling earning,
configure the rewarded ad unit's server-side verification callback to
`https://YOUR_BACKEND/api/rewards/ssv` in AdMob and verify database access.
Set `ADMOB_REWARDED_UNIT_IDS` to the allowed live rewarded ad unit IDs and
`ADMOB_REWARDS_ENABLED=true` in the backend environment, then deploy. The Neon
configuration passes both settings to the function and defaults earning to off.

Debug builds use Google test ads and never grant spendable coins. Live earning
requires a release build with valid publisher ad unit IDs and
`ADMOB_USE_TEST_ADS=false` in the Flutter environment. Only verified server
callbacks add coins; client ad-completion callbacks do not.

## Connect a Neon database

The backend uses the official `@neondatabase/serverless` driver over HTTPS.
Keep `DATABASE_URL` in `backend/.env` or in the backend host's environment.
It contains a database password and must not be copied into the Flutter root
`.env`, a mobile build, or a source file.

1. Create or select your project at [Neon](https://console.neon.tech).
2. Open **Connect**, select the database and role, and copy the PostgreSQL
   connection string into `backend/.env` as `DATABASE_URL`. Preserve the SSL
   parameters supplied by Neon.
3. From `backend`, run `npm install` followed by `npm run db:check`.
   The check runs `SELECT 1` and prints a success message or a safe error.
4. The backend exposes an authenticated `GET /api/database/health` endpoint
   for checking this connection with a Firebase ID token. The public `/health`
   endpoint remains independent of database availability.

The connection setup does not migrate favorites, authentication, movie files,
or download information. Those data models need to be selected before creating
tables. A hosted database also needs a hosted API for downloads to work away
from the PC. Neon Functions can host that API; connecting Postgres alone leaves
the current PC-hosted download service in place.

References: [Neon driver](https://neon.com/docs/serverless/serverless-driver),
[Neon Functions](https://neon.com/docs/compute/functions/overview).

## Authentication and endpoints

Public endpoints:

- `GET /health`
- `GET /api/catalogue/3/...` (allowlisted TMDB metadata; guest installation ID
  or a verified Firebase token, shared cache and rate limits)
- Account-deletion public pages and the independently verified AdMob SSV callback,
  as described in their rollout documentation

Firebase-authenticated endpoints include:

- `GET /api/database/health`
- `GET /api/wambesha/search`, `/titles`, `/genres` and `/lookup`
- `GET /api/wambesha/titles/:titleRef`, `/episodes` and `/sources`
- Rewards wallet/daily/session/redemption and account-deletion operations
- Legacy local-file `GET /api/movies`, `GET /api/movies/:id` and
  `POST /api/download/request`

The legacy `GET /api/download/stream` accepts a short-lived signed download
URL rather than a Firebase header. Provider credentials are never accepted
from the app. Only a 401 marked `firebase-auth` triggers one Firebase token
refresh; provider failures do not trigger automatic credential retries.

The retired `/api/mobile/*` and `/api/films365/*` routes return 404 and never
contact a provider. No retired-provider credential is needed for deployment.
Old investigation notes are preserved in [docs/archive](docs/archive) for
historical context only. Their commands and integration guidance are obsolete.

## Verification after deployment

Check `GET /health` returns 200. Without a Firebase token,
`GET /api/wambesha/genres` must return 401. With a guest installation header,
repeat a public catalogue request and confirm a shared cache HIT. Check retired
routes return 404. Then verify signed-in search, movie/episode source selection,
and offline playback on a device without printing tokens or delivery URLs.

Backend deployment does not build or update the installed mobile app.
