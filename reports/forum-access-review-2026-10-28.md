# Forum colors and shared access review

## Implemented locally

- Forum uses CinemaPalette: burgundy header, near-black background, dark cards, champagne-gold controls and warm ivory/muted text. Red remains for likes and destructive actions.
- Every installation uses the same Firebase project's `forum_posts` collection and `comments` subcollections. There is no country, device, localhost, account-owner or region filter on the feed. Categories and search still filter the shared discussions.
- Signed-in users post and reply with their real Firebase UID. Guests no longer write under a shared `anon` identity. This does not change sign-in or verification requirements elsewhere in the app.
- Like transactions read current membership and update its count together. Duplicate taps on a pending like or post are guarded.
- A reply and its parent count increment are committed as one batch. Failed replies retain typed text; failed posts retain the draft and allow retry.
- Feed errors show friendly messages and a retry action. Comment errors are no longer presented as an empty thread; close/reopen the thread to subscribe again.
- Owner deletion checks ownership on the server snapshot, cleans replies in bounded transactions before deleting the parent, and reports failures. Very large or actively changing discussions can still need trusted backend cleanup: deletion across multiple transactions is not globally atomic and a concurrent reply can race the final delete. Client checks do not replace Firestore rules.
- Added the category ASC / timestamp DESC index definition in `firestore.indexes.json`, referenced from `firebase.json`. This is local configuration only.

## What has not been verified

No Firestore rules file, deployed rules export, deployed index list, administrative Firebase tool or authenticated live test session was available. No production records were read or written. No credentials, authentication configuration, rules or cloud resources were changed. No deployment was performed.

Worldwide availability is not confirmed by local tests. Firestore access depends on its deployed rules, project/database availability, quotas, client connectivity and regional network restrictions. The app has no intentional geographic restriction; this cannot guarantee access from every country/network.

## Cloud checks still required

1. Confirm Cloud Firestore is enabled for the Firebase project already configured in the app.
2. Review existing deployed rules without replacing unrelated collections. Allow the intended users to read `forum_posts` and its `comments` subcollections. Require authenticated users to create records with `uid == request.auth.uid`. Validate field types, content limits, categories and server timestamps. Prevent clients from rewriting authors, owners or discussion content through like/count updates; validate allowed fields and atomic count/membership changes. Only owners or trusted moderators should delete posts and their replies. Reply creation must require an existing parent. Do not use a blanket public write rule or expiring test-mode rules.
3. Create/deploy the category/timestamp composite index from the supplied definition and wait for it to become ready. The All feed and comments use their ordinary timestamp indexes, which must also remain enabled.
4. Use two separate signed-in accounts/devices to check: A posts, B sees it, B likes and replies, A sees updates; verify owner-only deletion. Test All and category filters, denied access, connectivity loss/reconnect, and accounts on different networks/regions.
5. Before a public forum launch, complete content reporting, moderation and blocking workflows. This change does not add those features or establish AdMob/Play approval.

## Validation

- Eight service tests cover shared writes, real identities, transaction-based likes, missing posts, batched replies, failures, owner deletion checks and reply validation.
- Four screen tests cover guest write prevention, draft retention and duplicate post taps, failed reply retention, and feed error/retry behavior.
- These tests use in-memory SDK doubles. They do not test live security rules, actual multi-client transaction contention, regional reachability, or deployment.

## References

- [Firebase transactions and batched writes](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Firestore security rule conditions](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Firestore indexes](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Delete Firestore data and subcollections](https://firebase.google.com/docs/firestore/manage-data/delete-data)
