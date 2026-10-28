# FILMS365 success/failure comparison

Captured during app testing on October 21, 2026 (Africa/Nairobi, UTC+03:00).
This report uses existing backend traces; no new provider requests were made.

## What stayed the same

- Method: GET; endpoint: `/api/mobile/details`; content type: `movie`.
- Backend instance: `24a75419-916a-4a0a-9077-9d98353362cd`.
- Credential revision: `1` throughout these attempts.
- Within each pair, the logged movie identifier and identifier format match.

The revision is a process-local counter, not a credential or key hash.

## Pair A: provider ID

Provider ID: `7081e24a-0e13-43a5-8bcc-e95fcb345e50`.

| Nairobi time, Oct 21 | Status | Cache-Control | Age (seconds) | CF-Cache-Status | Duration |
|---|---|---|---|---|---|
| 01:48:51.602 +03:00 | 200 | public, s-maxage=43200 | 46525 | DYNAMIC | 104 ms |
| 01:49:08.681 +03:00 | 401 | private | not reported | DYNAMIC | 664 ms |

Request IDs:

- 200: `0033fd78-c1f7-4070-8754-3f54b8de8fae`.
- 401: `81f74953-f49d-4ae0-8fe3-e9d81c684a7f`.

Original UTC timestamps: `2026-10-20T22:48:51.602Z` and
`2026-10-20T22:49:08.681Z`.

## Pair B: TMDB identifier sent to FILMS365

TMDB ID: `1108427`. Both requests were to FILMS365, not the TMDB API.

| Nairobi time, Oct 21 | Status | Cache-Control | Age (seconds) | CF-Cache-Status | Duration |
|---|---|---|---|---|---|
| 01:48:48.998 +03:00 | 200 | public, s-maxage=43200 | 102997 | DYNAMIC | 337 ms |
| 01:50:12.097 +03:00 | 401 | private | not reported | DYNAMIC | 603 ms |

Request IDs:

- 200: `d5b9fa98-bded-41a0-94fc-61599ac82cd0`.
- 401: `036a52f4-cc81-4884-a20c-14e052267c43`.

Original UTC timestamps: `2026-10-20T22:48:48.998Z` and
`2026-10-20T22:50:12.097Z`.

## Interpretation and limits

Observed: the same logged identifier, backend instance, and credential revision
received both 200 and 401. Successful responses advertised shared caching and
reported an Age; denied responses were private and reported no Age. The user
also confirmed successful downloads and offline playback of two movies.

Inference: cached responses may explain why some attempts succeed while other
attempts reach an authentication check and fail. The traces do not identify the
cache layer, prove a cache defect, or establish that fresh authentication with
the current key succeeds. `CF-Cache-Status: DYNAMIC` does not rule out another
upstream cache. No movie titles were logged, so titles are not assigned to the
identifiers in this report without an independently verified mapping.

The HTTP 500 file-transfer report is a separate issue; these Details traces do
not diagnose it. Existing saved files remain playable without provider access.

## Questions for FILMS365 support

1. For the paired requests above, why did authentication outcomes differ?
2. Do the 200 responses originate from a shared cache, and is the current key
   accepted when Details requests are checked by the origin?
3. How are authorization and cache keys handled for movie Details?
4. Why do the successful Age values exceed the advertised s-maxage value?
5. Is there a supported way to verify key validity independently of cached data?

No keys, Firebase tokens, response bodies, or signed download links are included.
This report has not been sent to FILMS365.
