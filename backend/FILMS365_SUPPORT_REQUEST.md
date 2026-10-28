# FILMS365 support request

Subject: Details endpoint returns 401 Invalid API key

Update: successful downloads and offline playback were also confirmed. The
[paired trace comparison](FILMS365_TRACE_COMPARISON.md) documents 200 and 401
responses for the same logged identifier, backend instance, and credential
revision. Please investigate the difference; the cause remains unconfirmed.

Hello FILMS365 support,

We are integrating your mobile API through our backend. Please help verify our
account's API access and the authentication requirements for movie Details.

Our backend sends requests to:

```http
GET https://www.films365.org/api/mobile/details?type=movie&id=<FILMS365_MOVIE_ID>
Authorization: ApiKey <REDACTED>
```

The movie ID comes from your own catalogue. We also tested a released title,
Sonic the Hedgehog 3, rather than relying on upcoming movies from another source.

Observed failure response (successful responses also occurred):

```text
HTTP 401
{"error":"Invalid API key"}
```

Checks performed on October 21, 2026:

- Popular returns HTTP 200, including without an Authorization header.
- Details returns HTTP 401 with both an internal provider ID and a TMDB ID.
- The configured header follows the example on your public API documentation page.
- A fresh request with a cache-busting query parameter also returned HTTP 401.
- One earlier diagnostic run returned HTTP 200 with a nonempty HTTP downloadUrl,
  but subsequent runs returned HTTP 401. The cause of the difference is unknown.

Please confirm:

1. Whether our account/key is active and authorized for Details and downloads.
2. Whether `Authorization: ApiKey <key>` is the correct header for this endpoint.
3. Whether any expiry, IP restrictions, or account-specific permissions apply.
4. A supported example request that returns HTTP 200 for a released movie.
5. Whether `data.downloadUrl` points directly to a movie file, or requires further
   requests, headers, cookies, or torrent-link conversion, and how long it is valid.

Please provide any replacement credential through your secure account channel.
No API key, Firebase token, or download URL is included in this report.

Thank you.

---

## Local verification after support resolves access

1. Set the authorized key in `backend/.env` as `FILMS365_API_KEY`.
2. Stop the existing backend process in its terminal with Ctrl+C.
3. Run these commands from the project root:

   ```powershell
   cd backend
   npm run diagnose:films365
   ```

4. Confirm Details returns HTTP 200 and `data.downloadUrl` is a nonempty HTTP URL.
   A successful Details response alone does not prove the URL transfers a movie.
5. Start the backend with `npm start`, then hot restart the Flutter app.
6. Select the tested movie, tap Download Now, and select Download movie.
7. Check the `movie-file-transfer` status and wait for download completion.
8. Turn off networking, open Downloaded Movies, play the file, and seek forward.
9. If a step fails, record its status and error; omit full URLs and credentials.
