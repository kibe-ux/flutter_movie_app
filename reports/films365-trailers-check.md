# Film365 trailer/video metadata check — 30 October 2026

Three authenticated, read-only cURL requests were made using the key in
`backend/.env`: one trending request and one Details request each for a movie
and a TV show. All returned HTTP 200. No movie or episode media was downloaded.
The API key was passed to curl over stdin and is absent from these reports.

| Title | Details type | Trailer/video metadata |
| --- | --- | --- |
| Airplane Mode | movie | One YouTube trailer: `BaH8YyjbDZQ` |
| Lupin | tv | Official YouTube trailer: `ga0iTWXCGa0`; official teaser: `Y3tVDKuORi8` |

The relevant fields are `data.videos[]`: `name`, `site`, `type`, `key`, and
`official`. Film365 supplies YouTube IDs which the app can pass to its existing
YouTube embed player. The current `MovieInfoVideo.fromDetails` parser already
supports that structure; `MovieTrailers` displays the resulting videos.

Example request, with placeholders only:

```sh
curl --get "https://www.films365.org/api/mobile/details" \
  --header "Authorization: ApiKey YOUR_API_KEY" \
  --data-urlencode "type=tv" \
  --data-urlencode "tmdbId=YOUR_TMDB_ID"
```

Inspect `data.videos` in the JSON response. Alternatively, run
`node backend/scripts/inspect_films365_videos.js` from the repository root
to inspect a current movie and TV show without placing the key in command
arguments. Each run uses up to three provider API requests.

Movie Details also supplied populated `videoUrl` and `downloadUrl` strings;
TV Details supplied populated corresponding fields within season episodes.
Their presence does not establish that these URLs are playable, downloadable,
permanent, or trailer URLs. Those destinations were not requested.

The complete sanitized metadata inventory is in `films365-videos-check.json`.
YouTube availability and embed permission were not independently checked.
No application playback behavior or deployed backend settings were changed.
