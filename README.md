# Movie Hub

A Flutter app for discovering movies and TV shows, organising saved titles,
and joining a movie community. A Node.js backend provides catalogue access,
account services, and Cinema Rewards.

## Features

- Browse movies and TV shows, search by title, and explore genres.
- Keep favourites, My List, and watch history.
- Explore as a guest or sign in for account and community features.
- Join forum discussions, report content, and manage blocked users.
- Use Cinema Rewards and optional rewarded ads when enabled.
- Review privacy choices, account deletion, help, and legal information.

Android is the current device-testing target. Other platform folders are
included, but not every platform is configured or verified for release.

## Get started

Use Flutter **3.47.7**, the Android SDK, and Node.js **22 or later** for the backend.

1. Clone the repository and run `flutter pub get`.
2. Copy `.env.example` to `.env`, configure your backend URL, and keep test ads
   enabled. Provider API keys belong on the backend, not in the Flutter asset.
3. Configure Firebase and supply the ignored `lib/firebase_options.dart` and
   platform files such as `android/app/google-services.json`. Follow the
   [Firebase setup guide](https://firebase.google.com/docs/flutter/setup).
4. Follow the [backend setup](backend/README.md). The example address `10.0.2.2`
   is for an Android emulator; a physical phone needs a reachable backend URL.
5. Connect a device and run:

```sh
flutter devices
flutter run -d DEVICE_ID
```

Release signing and runtime details are in [Android setup](docs/APP_RUNTIME.md).
Real environment files, signing credentials, and Firebase configuration stay local.

## Project layout

| Folder | Purpose |
| --- | --- |
| `lib/screens/` | App pages and navigation |
| `lib/widgets/` | Shared UI components |
| `lib/services/` | APIs, accounts, ads, persistence, and transfers |
| `lib/models/`, `lib/config/`, `lib/utils/` | Data types, configuration, helpers |
| `assets/` | Bundled artwork and resources |
| `backend/` | Node.js API, tests, and deployment tools |
| `test/`, `integration_test/` | Unit/widget tests and device integration tests |
| `docs/` | Setup, architecture, operations, and testing guides |
| `docs/history/` | Historical reviews and implementation notes |
| `scripts/`, `tools/` | Development and diagnostic utilities |

## Checks

```sh
flutter analyze
flutter test
```

For backend checks:

```sh
cd backend
npm ci
npm test
```

[GitHub Actions](.github/workflows/checks.yml) runs analysis and tests on pushes
and pull requests. It uses CI-only Firebase placeholders, not production
credentials. It does not publish or deploy the app. Native ad rendering and
integration tests still require device verification.

Security release steps are in [abuse protection rollout](docs/SECURITY_ROLLOUT.md).

## Documentation and contributions

Start with the [documentation hub](docs/README.md),
[project structure](docs/PROJECT_STRUCTURE.md), and
[production runbook](docs/PRODUCTION_RUNBOOK.md).

Use focused branches, small commits, and short messages. Run relevant checks
before opening a pull request. Keep local editor state, generated files, and
credentials out of Git. AdMob test mode remains the development default;
passing tests does not constitute store or advertising approval.
