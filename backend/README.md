# Movie Download Backend

## Setup

1. Install dependencies:
   - `npm install`
2. From the repository root, copy `backend/.env.example` to `backend/.env`
   and set values:
   - `API_KEY`
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
asset or ship it in the app. The mobile proxy requires a Firebase ID token and
passes the documented endpoint path, HTTP method, query string, and request
body through without interpreting undocumented fields.

FILMS365 has not provided request parameter names or response schemas for its
mobile endpoints. The app therefore exposes decoded raw responses at the
service layer but does not map them into existing screens until the API
contracts are documented.

## Authentication

- Existing movie/download endpoints require the `x-api-key` header (or
  `apiKey` query parameter).
- FILMS365 proxy endpoints require `Authorization: Bearer <Firebase ID token>`.
- The upstream FILMS365 key is never accepted from a client request.
- Signed download URLs expire in 1 hour.

## Endpoints

- `GET /health`
- `GET /api/movies`
- `GET /api/movies/:id`
- `POST /api/download/request`
- `GET /api/download/stream`
