# Forum Firestore security

The forum rules are in `firestore.rules`. The target database is Movie Hub's Native-mode `(default)` database in Johannesburg (`africa-south1`). Deployment evidence is stored in `reports/firestore-security-2026-10-31/`.

Moderation deployment completed: the category/timestamp composite index and comment/block UID collection-group indexes are READY, and the downloaded production rule source matches all 30 passing emulator/readiness tests. Live unauthenticated checks returned 200 for the public forum feed and 403 for reports, membership, block lists, reward wallets, deletion jobs and an unknown collection. The moderator custom claim for `ngetichezra609@gmail.com` was granted and read back successfully. These checks did not create test users or application documents; signed-in production device flows still need checking after rebuilding the app.

## Access policy

- Guests can read public discussions and replies. Public records include the displayed author, avatar, Firebase UID and like membership; no account email or reward records are granted through these rules.
- Only authenticated, non-anonymous accounts without a deletion fence can write. Posting, replying and liking also require version 1 community-terms acceptance in `forum_members/{uid}`. Safety actions remain available without accepting contribution terms. A post's UID must match the authenticated account. Fields, lengths, categories, initial counters and server timestamps are validated. Extra fields are rejected.
- Ownership and timestamps are immutable. Ordinary members cannot edit content or author fields. A member can toggle only their own like and must supply its exact count, with no duplicates or changes to other memberships.
- A reply and its parent's increment must be committed together. The parent's `lastCommentId` identifies a newly created reply from the caller. Replay, phantom count updates, two replies for one increment, mismatched IDs and missing parents are denied.
- An owner marks a discussion `deleting: true` before removing replies. That state cannot be reversed; new likes/replies are denied while cleanup runs. Only the owner can remove its replies and parent. The backend handles account-wide erasure.
- Account deletion fences stop writes by that account and prevent other accounts from adding likes/replies on its posts.
- `users`, deletion jobs, all reward collections and unspecified paths remain inaccessible to clients. Trusted Admin SDK access is governed separately by IAM.

## Reporting, blocking and moderation

The post/reply menu offers Report content, Report user and Block user. Reports must identify real source content and its actual author; reporter identity, reason, length, timestamp and initial status are validated. A deterministic document ID prevents repeat reports for the same reporter, target type and source. Only moderators can read reports, including the reporter's identity and additional details. Reporters cannot edit or read submitted reports. Reports do not copy the offending body into a second collection.

Block lists are private to their owner. The app hides blocked authors' posts and replies, and server rules reject replies/likes in both directions on either account's posts. Blocking does not make public content confidential: guests can still read it, and both users can participate in another person's thread. Unblocking is available from the forum header. New block records require an existing member and cannot target an account undergoing deletion.

The moderator shield opens a queue of open reports with the source content and Dismiss/Remove controls. Server authorization requires a trusted `moderator: true` custom claim; client documents cannot grant this role. Removal replaces the source body and displayed identity with fixed notices. A removed discussion's replies become readable only by moderators. Report resolution and removal happen atomically; moderators cannot resolve a report as removed without an actual removed target. No account banning workflow is included.

The selected moderator account is `ngetichezra609@gmail.com`. `scripts/configure_forum_moderator.cjs --grant C:/nvm/nodejs/node_modules/firebase-tools` checks the exact, enabled, email-verified app account, preserves existing claims, sets the moderator claim and reads it back. Reopen the forum after signing in with the rebuilt app; it refreshes the ID token to obtain the role. Firebase custom claims remain the authoritative role source.

Reports remain until account cleanup or a separately defined retention process removes them; define operational retention before public launch. Account deletion removes reports submitted by or targeting the account, anonymizes its reviewer identity on other reports, and removes terms acceptance and incoming/outgoing blocks. The deletion fence prevents those records being recreated during cleanup. Moderators must review reports regularly; the queue does not automatically detect abusive content or notify staff.

## Required app changes

New posts include `deleting: false` and `lastCommentId: null`. Reply batches include `lastCommentId` alongside the count increment. Owner deletion starts by marking the parent as deleting. These changes are implemented in `lib/services/forum_service.dart`.

**Rebuild and install the updated app before testing posts/replies.** Older builds omit required fields and their writes will be denied. No database migration was needed because this database was newly created and no production application records were written during setup.

## Validation

Thirty tests passed using Google's actual Firestore emulator 1.22.0 and the rule source in the repo. They cover public queries, valid member operations, anonymous/guest write denial, spoofing, malformed data, arbitrary edits, likes, atomic counts, replay, orphan creation, deletion ownership and races, account fences, private collection access, contribution terms, private reports, blocks, moderator tombstones and atomic report decisions. Two tests prove the production publication gate rejects CREATING, failed, missing and unverified indexes.

The tests use a dependency-free Node REST transport and unsigned mock identities accepted only by the emulator. Assertions require actual HTTP 403 `PERMISSION_DENIED` responses for denied operations; generic failures do not count as passing security tests. The runner binds to `127.0.0.1`, uses a demo project, refuses an occupied port, verifies Google's emulator SHA-256 checksum and stops only its own Java process. No production user credentials or application documents are used.

Dart static analysis passed for the changed screens, service, safety widgets and affected client tests. Four backend account-deletion tests passed, including cleanup of reports, reviewer identity, membership and blocks. Using the IDE's SDK at `C:/Users/Hezra/.android/flutter`, all seven forum widget tests now pass, including reporting-menu visibility for another account's post and controller lifetime during reply-sheet dismissal. The earlier native-assets blocker applied to the other installed SDK. Tests use InkRipple to avoid an unrelated cached InkSparkle shader incompatibility.

## Device debugging

A hot restart confirmed current source in the Dart VM, but reopening the installed old app restored its bundled old Dart code. That old service omitted `deleting` and `lastCommentId`, causing write denial, and had no reporting menu. A persistent APK update is required; a successful hot restart alone does not establish that the installed APK contains the changes. Verify the runtime source after reopening when diagnosing this mismatch.

Reply-sheet dismissal also exposed a controller-lifetime bug: the modal Future completes before its exit animation unmounts the text field. The reply controller now belongs to the sheet's State and is disposed on unmount, rather than in `whenComplete`. A regression test rebuilds the outgoing sheet during a keyboard-metrics change and verifies dismissal without exceptions.

The connected development phone uses `com.moviehub.app`, while the repository's default application ID remains `com.example.movie_hub`. `tools/android_local_debug.init.gradle` is an opt-in, debug-task-only override for updating that existing local package; it does not change release identity. Do not uninstall or clear account data to work around a signing mismatch.

The corrected ARM64 debug APK was built successfully and installed with `adb install -r -t`, preserving app data. A fresh launch initialized Firebase successfully. Read-only Dart VM inspection confirmed the installed forum service, screen and safety-widget sources exactly match the workspace; `reports/forum-debug-device-verification.json` records those checks. No hot restart was used for this verification. Seven forum widget tests and final static analysis passed. Actual report submission and moderator review with the user's two accounts still require device confirmation.

## Run tests

Use Node 22+ and Java 21+. On this machine, Java 21 is bundled with Android Studio; no global Java setting needs to change. No npm installation is required.

Download the official emulator once into the ignored test cache:

```powershell
New-Item -ItemType Directory -Force tools/firestore-tests/.emulator | Out-Null
curl.exe --fail --location --output tools/firestore-tests/.emulator/cloud-firestore-emulator-v1.22.0.jar https://storage.googleapis.com/firebase-preview-drop/emulator/cloud-firestore-emulator-v1.22.0.jar
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
node tools/firestore-tests/run_emulator.cjs
```

The expected SHA-256 comes from the installed Firebase CLI's official emulator metadata: `9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c`. After a successful run, `forum-rules-tests.json` records the rule and test-source hashes.

## Deployment

The standard Firebase CLI launcher stalled on this machine, so `scripts/deploy_forum_security.cjs` uses Google's Rules and Firestore Admin APIs through the saved Firebase login, without printing token values. It requires matching passing-test hashes, checks the Johannesburg database, refuses unexpected deployed rule changes, creates only missing declared composite indexes, configures the declared comment and blocked UID field indexes, waits for readiness, then publishes and reads back the tested rules. Immediately before publishing it re-reads every index and calls a tested fail-closed readiness gate. It does not delete unrelated indexes, alter billing or IAM, or write application documents.

```powershell
node scripts/deploy_forum_security.cjs --plan
# Requires authorized production deployment:
node scripts/deploy_forum_security.cjs --apply C:/nvm/nodejs/node_modules/firebase-tools
```

Later rule changes must match the last verified deployment hash, the reviewed bootstrap, or the already-tested target source. The prior deployment record must identify this exact project and database and contain passing-test and READY-index evidence. An unrelated production change stops publication and requires review.

## Remaining work

Rebuild and check reporting, blocking/unblocking and moderator review with two signed-in devices. Confirm your moderator shield appears after sign-in, report a post and reply from the other account, then dismiss/remove through the queue. Confirm blocked authors disappear and replies/likes are denied in both directions. Check cancellation of community terms prevents contributions and accepting permits them. App Check, API rate limits and usage/budget alerts remain separate security tasks. Account deletion remains disabled until its backend deployment, scheduled retry worker, external sign-in page and end-to-end checks are complete; see `account-deletion-rollout.md`.

## References

- [Firestore security conditions and atomic operations](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Testing Firestore rules with the emulator](https://firebase.google.com/docs/firestore/security/test-rules-emulator)
