# Movie Download Backend

## Setup

1. Install dependencies:
   - `npm install`
2. From the repository root, copy `backend/.env.example` to `backend/.env`
   and set values:
   - `JWT_SECRET`
   - `PORT` (optional, default `3000`)
   - `FIREBASE_PROJECT_ID`
   - `FILMS365_API_KEY`
3. Configure Google Application Default Credentials for the Firebase project
   (for example, set `GOOGLE_APPLICATION_CREDENTIALS` to a service-account
   file outside source control, or use the hosting platform's workload identity).
   Never commit service-account credentials.
4. Put movie files in `backend/movies/` using names like:
   - `Movie.Name.2023.1080p.mp4`
5. Start server:
   - `npm start`

The FILMS365 key is sent only by this backend to `https://www.films365.org`
with `Authorization: ApiKey ...`. Do not keep that key in the Flutter `.env`
asset or ship it in the app. The mobile proxy requires a Firebase ID token and passes the endpoint path,
HTTP method, query string, and request body through without logging credentials
or interpreting response data.

## Hosted download API on Neon

The current download API is deployed to the `moviehub` function on the
`production` branch of project `summer-shadow-58564268`:

`https://br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech`

The Flutter root `.env` points to this address. Rebuild and install the app after
changing that asset; an APK installed with the old PC address keeps using it.

From `backend`, use:

- `npm run neon:build` to build and check that private settings are excluded.
- `npm run neon:plan` to preview deployment changes.
- `npm run neon:deploy` to deploy the function and its private environment.
- `npm run neon:status` to print its public URL and deployment status.

`neon.ts` declares the function; `functions/moviehub/index.mjs` wraps the existing
Express API through `neon_http.js`. Firebase ID token verification and the
Film365 proxy routes remain active. API responses use `Cache-Control: no-store`.
The Film365 key stays in the function environment, and Neon injects the branch's
database connection. Neither credential belongs in the Flutter app.

Movie files from Film365 are downloaded by the phone directly from the returned
provider URLs. The legacy local-file catalogue only lists files on the backend's
own filesystem; PC movie files are not uploaded by this deployment.

To build the configured Android release APK from the repository root, use the
Flutter SDK configured in `android/local.properties`:

```powershell
flutter build apk --release
```

Install `build/app/outputs/flutter-apk/app-release.apk`, sign in, then test a new
download on mobile data with the PC disconnected. Existing saved movies remain
in the app's local storage when updating with the same application ID and key.

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

## Deploy to Cloud Run

1. Select the same Google Cloud/Firebase project configured in the Flutter
   application, enable billing, and enable Cloud Run, Cloud Build, Artifact
   Registry, and Secret Manager APIs.
2. Create a dedicated Cloud Run runtime service account.
3. In Secret Manager, create secrets named `films365-api-key` and
   `films365-jwt-secret`. Enter the existing FILMS365 key directly in the
   Secret Manager console. Generate a long random JWT signing secret. Do not
   put either value in a command, source file, or container image.
4. Grant the runtime service account the Secret Manager Secret Accessor role
   on those two secrets.
5. From the repository root, deploy the backend source:

   ```powershell
   gcloud run deploy films365-backend `
     --source .\backend `
     --region YOUR_REGION `
     --service-account YOUR_RUNTIME_SERVICE_ACCOUNT `
     --allow-unauthenticated `
     --set-env-vars FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
     --set-secrets "FILMS365_API_KEY=films365-api-key:latest,JWT_SECRET=films365-jwt-secret:latest"
   ```

   Cloud Run must accept network requests from mobile clients; application
   routes validate Firebase ID tokens themselves. `/health` is public, and the
   stream endpoint accepts only the signed, expiring URL returned after an
   authenticated download request.
6. After deployment, copy the service's HTTPS URL into the Flutter root `.env`
   as `MOVIE_DOWNLOAD_API_BASE_URL=https://YOUR_CLOUD_RUN_URL`. Rebuild/restart
   the Flutter app after changing the asset. Never put the FILMS365 key there.
7. Check `GET /health` returns 200 and an unauthenticated
   `GET /api/films365/trending` returns 401. Then, while signed into the app,
   make an authenticated request through `Films365ApiService` and verify the
   upstream response status and data. Do not log or share the Firebase ID token.

The backend source ignore file excludes `.env` files and `node_modules` from
the Cloud Run source upload. The Firebase Admin SDK uses the attached Cloud Run
service identity through Application Default Credentials; do not upload a
service-account JSON key.

The current OpenAPI contract is available at
`https://www.films365.org/api/mobile/doc`. It describes the trending, popular,
latest, explore, search, details, and person operations, including movie and TV
list-item schemas. The Flutter service sends these documented request
parameters and leaves responses decoded but otherwise unmodified. Existing
catalogue screens are not switched to FILMS365 until a real authenticated
response has been verified and its fields can be safely mapped.

The proxy also accepts `POST /api/films365/details/torrent-link` with a JSON
`link` body as specified for this integration. This operation is not present
in the current published OpenAPI document.

## Authentication

### Check FILMS365 download access

The [October 23 live check](FILMS365_DOWNLOAD_CHECK_2026-10-23.md) reproduces
Details/Search 401 responses and a returned file URL responding with 500.
Use `node scripts/check_movie_downloads.js` for a compact comparison of five
popular movies, or add a quoted title to compare search results. `--probe`
checks returned URLs with a cancelled byte-range request and never saves movies.

The user has verified downloads and offline playback for Spider-Man: Brand New
Day and The Odyssey, despite earlier 401 failures. Treat the authorization issue
as intermittent; its cause is not established by the earlier rejection alone.

### Compare failed and successful requests

The backend logs `UPSTREAM_RESULT` or `UPSTREAM_FAIL` followed by JSON containing
UTC time, request ID, movie ID (or TMDB ID), content type, status, elapsed time,
backend instance, credential revision, and allowlisted cache-header values.
Credential revision is a counter within one backend process; it contains no key
material or key hash. Compare revision only within the same backend instance.
The logs exclude response bodies, credentials, search queries, and download URLs.

Flutter debug logs include the returned `X-MovieHub-Request-Id` and
`X-MovieHub-Backend-Instance`, allowing a device failure to be matched to its
backend trace. Compare attempts for the same identifier and content type, on the
same instance and credential revision. Keep both trace lines for provider support
if the status changes. Cache metadata is evidence to compare, not proof of cause.

A FILMS365 401 does not trigger automatic token refresh or upstream retries.
The user can retry manually. Only a 401 attributed to Firebase authentication
refreshes the Firebase ID token once. Saved movies remain available offline.

### Diagnostic command and historical checks

Use [the prepared support request](FILMS365_SUPPORT_REQUEST.md) when contacting
FILMS365. It includes the observed failures and a download verification checklist.

Run `npm run diagnose:films365` from `backend`, or
`npm run diagnose:films365 -- --id <provider-id>` for a specific movie.
The command uses the backend key and prints HTTP statuses and JSON field
types only. It does not print credentials, download links, or response values.

On October 21, 2026, Popular returned 200 even without an Authorization header.
Catalogue success therefore does not validate the API key. Details rejected the
configured key with 401 and `Invalid API key`, including when a valid provider
ID was supplied. Both `ApiKey` and `Bearer` were tested and rejected.

The raw specification declares `BearerAuth` but references undefined
`ApiKeyAuth` on Details. The public documentation page at
`https://www.films365.org/api/docs` explicitly replaces that definition with
an `Authorization` header formatted as `ApiKey YOUR_API_KEY`. This matches
the existing proxy. Keep that format; obtain a valid FILMS365 key with Details
access and set `FILMS365_API_KEY` on the running backend. A Flutter hot restart
does not reload backend environment variables; restart the Node server after
changing `backend/.env`, or update the deployed server's secret and redeploy.

The Details schema specifies only `data.id` and `data.type`; it does not
document a downloadable file field. The torrent-link operation also leaves
its response schema unspecified. Live successful movie Details responses have
now verified `data.downloadUrl` as an absolute HTTP URL. URL presence alone does
not guarantee a movie transfer; the October 23 check reproduced a 500 from one
such URL.
A torrent or magnet link requires a torrent client and cannot be saved as a
movie by the app's current HTTP file downloader.

- Movie catalogue, download URL, and FILMS365 proxy endpoints require
  `Authorization: Bearer <Firebase ID token>`.
- The streaming endpoint accepts only a short-lived signed JWT URL returned
  after authenticated download authorization.
- The upstream FILMS365 key is never accepted from a client request.
- Signed download URLs expire in 1 hour.

## Endpoints

- `GET /health`
- `GET /api/movies`
- `GET /api/movies/:id`
- `POST /api/download/request`
- `GET /api/download/stream`
- `GET /api/films365/trending`
- `GET /api/films365/popular`
- `GET /api/films365/latest`
- `GET /api/films365/explore`
- `GET /api/films365/details`
- `POST /api/films365/search`
- `GET /api/films365/person`
- `POST /api/films365/details/torrent-link` (not in the published OpenAPI document)
