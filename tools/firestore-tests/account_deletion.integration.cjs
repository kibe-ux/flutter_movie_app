const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const backend = path.resolve(__dirname, '../../backend');
const { getAuth } = require(require.resolve('firebase-admin/auth', { paths: [backend] }));
const { getFirestore } = require(require.resolve('firebase-admin/firestore', { paths: [backend] }));
const { getRuntimeFirebaseApp } = require('../../backend/firebase_runtime');
const { createAccountDeletion } = require('../../backend/account_deletion');
let auth, db, server, origin, hosted;
const password = crypto.randomBytes(24).toString('base64url');
const alice = 'deletion-test-alice', bob = 'deletion-test-bob';
async function signIn(uid) {
  const r = await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `${uid}@example.test`, password, returnSecureToken: true }),
  });
  assert.equal(r.status, 200);
  return (await r.json()).idToken;
}
function oldAuthentication(token) {
  const claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url'));
  claims.auth_time -= 301;
  // Unsigned tokens are accepted ONLY by the isolated Auth emulator.
  return Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url') + '.' +
    Buffer.from(JSON.stringify(claims)).toString('base64url') + '.';
}
before(async () => {
  assert.equal(process.env.FIREBASE_PROJECT_ID, 'demo-moviehub-deletion');
  assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9098');
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8085');
  const app = getRuntimeFirebaseApp();
  auth = getAuth(app); db = getFirestore(app);
  for (const uid of [alice, bob]) await auth.createUser({ uid, email: `${uid}@example.test`, password });
  const api = require('../../backend/server');
  server = api.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
  hosted = (await import(pathToFileURL(path.join(backend, '.neon-build/index.mjs')))).default;
});
after(async () => {
  if (server) { server.closeAllConnections(); server.close(); }
  if (db) await db.terminate();
});

test('HTTP and hosted bundle reject unauthenticated, stale and anonymous deletion without erasing users', async () => {
  assert.equal((await fetch(origin + '/api/account', { method: 'DELETE' })).status, 401);
  const token = await signIn(alice);
  const stale = await fetch(origin + '/api/account', { method: 'DELETE', headers: { Authorization: 'Bearer ' + oldAuthentication(token) } });
  assert.equal(stale.status, 401);
  const r = await fetch('http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ returnSecureToken: true }),
  });
  const anonymous = (await r.json()).idToken;
  assert.equal((await fetch(origin + '/api/account', { method: 'DELETE', headers: { Authorization: 'Bearer ' + anonymous } })).status, 403);
  const bundled = await hosted.fetch(new Request('https://emulator.example/api/account', {
    method: 'DELETE', headers: { Authorization: 'Bearer ' + oldAuthentication(token) },
  }));
  assert.equal(bundled.status, 401);
  assert.equal((await auth.getUser(alice)).uid, alice);
});

test('real Admin cleanup erases only the authenticated account, recursively, with Auth last', async () => {
  const entries = {
    [`forum_posts/own`]: { uid: alice, likedBy: [], likes: 0, commentCount: 1 },
    [`forum_posts/own/comments/bob`]: { uid: bob },
    [`forum_posts/other`]: { uid: bob, likedBy: [alice, bob], likes: 2, commentCount: 2 },
    [`forum_posts/other/comments/alice`]: { uid: alice },
    [`forum_posts/other/comments/bob`]: { uid: bob },
    [`forum_posts/missing/comments/orphan`]: { uid: alice },
    [`reward_sessions/a`]: { uid: alice }, [`reward_receipts/a`]: { uid: alice },
    [`reward_accounts/${alice}`]: { coins: 10 }, [`reward_accounts/${alice}/passes/a`]: { earned: true },
    [`reward_accounts/${bob}`]: { coins: 20 }, [`users/${alice}/saved/a`]: { saved: true },
    [`forum_members/${alice}`]: { termsVersion: 1 },
    [`forum_members/${alice}/blocked/${bob}`]: { uid: bob },
    [`forum_members/${bob}/blocked/${alice}`]: { uid: alice },
    [`forum_reports/authored`]: { reporterUid: alice, targetUid: bob },
    [`forum_reports/targeted`]: { reporterUid: bob, targetUid: alice },
    [`forum_reports/reviewed`]: { reporterUid: bob, targetUid: bob, reviewedBy: alice, status: 'dismissed' },
  };
  const batch = db.batch();
  for (const [name, data] of Object.entries(entries)) batch.set(db.doc(name), data);
  await batch.commit();
  const originalDelete = auth.deleteUser.bind(auth);
  let authLastChecked = false;
  auth.deleteUser = async uid => {
    assert.equal(uid, alice);
    assert.equal((await db.collectionGroup('comments').where('uid', '==', alice).get()).empty, true);
    assert.equal((await db.doc(`reward_accounts/${alice}`).get()).exists, false);
    assert.equal((await db.doc(`forum_members/${alice}`).get()).exists, false);
    authLastChecked = true;
    return originalDelete(uid);
  };
  const result = await fetch(origin + '/api/account', { method: 'DELETE',
    headers: { Authorization: 'Bearer ' + await signIn(alice), 'Content-Type': 'application/json' },
    body: JSON.stringify({ uid: bob }),
  });
  assert.equal(result.status, 200);
  assert.equal((await result.json()).status, 'complete');
  assert.equal(authLastChecked, true);
  await assert.rejects(auth.getUser(alice), error => error.code === 'auth/user-not-found');
  assert.equal((await auth.getUser(bob)).uid, bob);
  assert.equal((await db.doc('forum_posts/own/comments/bob').get()).exists, false);
  const other = (await db.doc('forum_posts/other').get()).data();
  assert.deepEqual(other.likedBy, [bob]); assert.equal(other.likes, 1); assert.equal(other.commentCount, 1);
  assert.equal((await db.doc('forum_posts/other/comments/bob').get()).exists, true);
  assert.equal((await db.doc(`users/${alice}/saved/a`).get()).exists, false);
  assert.equal((await db.doc(`forum_members/${bob}/blocked/${alice}`).get()).exists, false);
  assert.equal((await db.doc('forum_reports/authored').get()).exists, false);
  assert.equal((await db.doc('forum_reports/targeted').get()).exists, false);
  assert.equal((await db.doc('forum_reports/reviewed').get()).data().reviewedBy, undefined);
  assert.equal((await db.doc(`reward_accounts/${bob}`).get()).data().coins, 20);
  assert.equal((await db.doc(`account_deletions/${alice}`).get()).data().status, 'complete');
  auth.deleteUser = originalDelete;
});

test('bundled hosted handler can perform cleanup with real SDKs and worker purges retained fences', async () => {
  const response = await hosted.fetch(new Request('https://emulator.example/api/account', {
    method: 'DELETE', headers: { Authorization: 'Bearer ' + await signIn(bob) },
  }));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).status, 'complete');
  await assert.rejects(auth.getUser(bob), error => error.code === 'auth/user-not-found');
  const worker = createAccountDeletion({ db, auth, now: () => Date.now() + 8 * 86400000 });
  const result = await worker.retryPending();
  assert.equal(result.purgedFences, 2);
});

test('deployed worker bundle resumes an interrupted deletion through real Auth and Firestore', async () => {
  const uid = 'deletion-test-retry';
  await auth.createUser({ uid, email: `${uid}@example.test`, password });
  await db.doc(`reward_accounts/${uid}/passes/a`).set({ earned: true });
  const originalDelete = auth.deleteUser.bind(auth);
  auth.deleteUser = async () => { throw Error('Simulated interruption'); };
  try {
    const result = await createAccountDeletion({ db, auth }).request({ uid, auth_time: Math.floor(Date.now() / 1000), firebase: { sign_in_provider: 'password' } });
    assert.equal(result.status, 'pending');
    assert.equal((await auth.getUser(uid)).uid, uid);
  } finally { auth.deleteUser = originalDelete; }
  const worker = (await import(pathToFileURL(path.join(backend, '.neon-build/accountcleanup/index.mjs')))).default;
  const response = await worker.fetch(new Request('https://worker.example/', { method: 'POST',
    headers: { 'x-neon-trigger-invocation-id': 'local-run' },
    body: JSON.stringify({ invocation_id: 'local-run', data: { scheduled_at: new Date().toISOString() } }),
  }));
  assert.equal(response.status, 200);
  await assert.rejects(auth.getUser(uid), error => error.code === 'auth/user-not-found');
  assert.equal((await db.doc(`account_deletions/${uid}`).get()).data().status, 'complete');
  const out = path.resolve(__dirname, '../../reports/account-deletion-rollout');
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'real-emulator-integration.json'), JSON.stringify({
    passed: true, productionAccountsUsed: false, projectId: process.env.FIREBASE_PROJECT_ID,
    realAuthAndFirestore: true, hostedBundleVerified: true, workerBundleVerified: true,
    apiBundleSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(backend, '.neon-build/index.mjs'))).digest('hex'),
    workerBundleSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(backend, '.neon-build/accountcleanup/index.mjs'))).digest('hex'),
    checkedAtUtc: new Date().toISOString(),
  }, null, 2) + '\n');
});

test('real browser verifies password, cancellation and acknowledged account deletion', async () => {
  const { browserDeletionCheck } = require('./browser_deletion_check.cjs');
  await browserDeletionCheck({ auth, db, password });
});
