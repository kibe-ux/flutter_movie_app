# Project structure

The Flutter application starts in `lib/main.dart`. Use these folders consistently:

| Folder | Contents |
| --- | --- |
| `lib/screens/` | Complete pages and navigation shells, named `*_screen.dart` |
| `lib/widgets/` | Reusable UI components, with no page-level navigation ownership |
| `lib/services/` | API clients, authentication, ads, downloads, caching and persistence |
| `lib/models/` | Data types and their serialization; no network or UI work |
| `lib/config/` | Configuration and catalogue category definitions |
| `lib/utils/` | Shared formatting, validation, presentation helpers and styling constants |
| `test/` | Unit/widget tests grouped by the production responsibility they test |
| `integration_test/` | Tests that exercise Android behavior on a device |
| `docs/history/` | Historical implementation notes; not current product instructions |
| `backend/` | Node backend, quota guards, API routes and database integration |

## Titles

`screens/title_details_screen.dart` contains `TitleDetailsScreen`, shared by movie
and TV navigation. Home, Explore, Search and saved lists all use this screen.
There is no second movie-details screen or separate legacy download navigation.

Saved-list persistence lives in `services/my_list_service.dart` as
`MyListService`; it is state/storage logic, not a formatting utility. Backend
address validation lives in `utils/backend_url.dart` and is shared by API clients.

## Downloads

`services/download_service.dart` is the only transfer engine. It owns the queue,
progress updates, pause/cancel handling and completed-file handling. Supporting
services have narrower responsibilities:

- `download_background_service.dart`: Android foreground-service bridge.
- `download_queue_store.dart`: durable, checked queue snapshots.
- `download_source_request.dart`: serializable provider identity and link renewal.
- `queued_download_source.dart`: reuse valid links and preserve source selection.
- `validated_download_response.dart`: ETag, size and range checks before appending.

`models/download_item.dart` holds progress/status data, and
`models/downloaded_movie.dart` holds saved-file metadata. Progress text formatting
lives in `utils/download_progress.dart`, separate from its rendering widget.

The removed Downloads page and queue widget must not be added back as part of a
structural refactor. External browser/ADM downloads, link copying, provider
subtitle links and trailers remain in the active title-details flow.

## Cleanup decisions

The obsolete movie-list/download-shell/detail stack and `MovieDownloadService`
were unreachable from application navigation. Their duplicate transfer code,
models and tests were retired. Shared source-selection tests now use
`WambeshaApiService` directly; integrity, queue and recovery tests cover the
active downloader.

The unused `screens/services/` files duplicated existing metadata functionality
or were empty, so they were removed rather than relocated. Unreferenced discovery
definitions, theme/recommendation/analytics helpers, a rating-dialog experiment,
and an unreachable standalone player/subtitle-import stack were also removed.
Their package-only dependencies and tests were retired with them. This does not
remove the active external playback/download or subtitle-link options.

The Firebase Analytics SDK remains installed even though its unused Dart wrapper
was removed: it also provides [automatically collected events](https://firebase.google.com/docs/analytics/events).

## Verification

Run `flutter analyze` and `flutter test` after moving public classes or files.
Run `flutter test integration_test/background_download_test.dart -d DEVICE_ID`
when changing the Android foreground-service lifecycle. Keep import paths and
tests aligned with the folders above; do not create service folders inside
`screens/`.
