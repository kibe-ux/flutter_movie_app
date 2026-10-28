# Film365 release download check — October 27, 2026

The installed release reports that Film365 denied access when loading movie
details. This check did not change the APK, deployment, credentials, or data.

## Observations

- The hosted Neon `/health` endpoint returned HTTP 200.
- Hosted function logs around 10:09–10:10 UTC show popular, trending, and latest
  requests returning 200. Search and details requests returned upstream 401.
- The failed details request used movie TMDB ID `1400940`. One trace at
  `2026-10-27T10:10:01.876Z` has request ID
  `4e396fb7-f0a5-4b21-9f9e-87b7de91472a`, backend instance
  `772be156-79be-464d-b568-940d254af40c`, and credential revision 1.
- A direct request from the PC with the backend's configured key also returned
  401 for TMDB ID `1400940`.
- A direct comparison for Sonic the Hedgehog 3, TMDB ID `939243`, returned 401
  for both provider-ID and TMDB-ID details lookups.
- After the user identified Spider-Man as a previous successful download, a
  search for Spider-Man: Brand New Day returned 401. A direct Details lookup for
  that title, TMDB ID `969681`, also returned 401. The diagnostic confirmed that
  the error response contained `Invalid API key`, without printing the body or
  credentials. This test used the current local backend key, not an authenticated
  end-to-end request through Neon. The specific Spider-Man installment remains
  an assumption based on the earlier success recorded in backend/README.md.
- An earlier direct diagnostic during this session returned 200 for one popular
  movie's details and included a download URL. Its movie ID was not recorded in
  that diagnostic output. This success does not establish access for the movies
  that failed, or prove a stable credential or routing difference.

## Interpretation and next step

### TV follow-up: Bleach

The user also reported `Download unavailable` for Bleach. TMDB returned 200 and
confirmed the title for series ID `30984`. The hosted trace at
`2026-10-27T10:16:23.049Z` records Film365 Details returning 401 for that TV ID.
A direct provider check for `type=tv&tmdbId=30984` also returned 401, with the
diagnostic confirming `Invalid API key` in the error response.

The current UI conflates failed metadata loading with missing episode links:
`_loadFilms365Metadata()` catches the initial details exception and returns null,
and `TvSeasonsSection` labels an episode `Download unavailable` when no matching
HTTP download URL exists in that metadata. Therefore this observed label does
not establish that Bleach's episodes have no downloadable files. Episode-link
availability cannot be verified until the provider details request succeeds.

The observed download preparation failure is an upstream Film365 authorization
rejection. Hosted requests reached the provider after passing the backend's
Firebase token verification. The exact reason for the provider rejection is not
established; a 401 alone does not establish that the key is universally invalid.

Ask Film365 to check Search and Details access for the account/key using the
timestamp, request trace, and movie IDs above. Compare an accepted and rejected
request for the same movie if the provider can reproduce the intermittent result.
Do not send passwords, Firebase tokens, API keys, or signed download URLs in a
public support report. No movie transfer was verified by this check.
