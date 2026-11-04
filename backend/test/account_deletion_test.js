const test = require('node:test');
const assert = require('node:assert/strict');
const { createAccountDeletion, requireRecentIdentity, registerAccountDeletionRoutes } = require('../account_deletion');

// Serial transactions model atomic read/write behavior; recursive deletion also
// removes descendants whose parent document is already missing.
function store() {
  const data = new Map();
  let tail = Promise.resolve();
  const snapshot = (path) => ({ id: path.split('/').pop(), ref: ref(path),
    exists: data.has(path), data: () => structuredClone(data.get(path)) });
  function query(path, group = false, filters = [], count = Infinity, cursor) {
    return { id: path.split('/').pop(),
      parent: path.includes('/') ? ref(path.split('/').slice(0, -1).join('/')) : null,
      doc: (id) => ref(`${path}/${id}`),
      where: (field, op, value) => query(path, group, [...filters, [field, op, value]], count),
      limit: (n) => query(path, group, filters, n),
      startAfter: (doc) => query(path, group, filters, count, doc.id),
      get: async () => {
        const docs = [...data].filter(([key, value]) => {
          const parts = key.split('/');
          if (cursor && parts.at(-1) <= cursor) return false;
          if (group ? parts.at(-2) !== path : parts.slice(0, -1).join('/') !== path) return false;
          return filters.every(([field, op, expected]) => op === '==' ? value[field] === expected :
            op === '<=' ? value[field] <= expected : (value[field] || []).includes(expected));
        }).slice(0, count).map(([key]) => snapshot(key));
        return { docs, empty: !docs.length };
      },
    };
  }
  function ref(path) {
    return { path, parent: query(path.split('/').slice(0, -1).join('/')),
      get: async () => snapshot(path), collection: (name) => query(`${path}/${name}`),
      set: async (value) => data.set(path, structuredClone(value)),
      delete: async () => data.delete(path) };
  }
  return { data, collection: (name) => query(name), collectionGroup: (name) => query(name, true),
    recursiveDelete: async (reference) => {
      for (const key of data.keys()) if (key === reference.path || key.startsWith(reference.path + '/')) data.delete(key);
    },
    runTransaction(callback) {
      const result = tail.then(async () => {
        const writes = [];
        const result = await callback({ get: (ref) => ref.get(),
          set: (ref, value) => writes.push(() => data.set(ref.path, structuredClone(value))),
          update: (ref, value) => writes.push(() => data.set(ref.path, { ...data.get(ref.path), ...value })),
          delete: (ref) => writes.push(() => data.delete(ref.path)) });
        writes.forEach((write) => write());
        return result;
      });
      tail = result.catch(() => {});
      return result;
    },
  };
}
const time = 1800000000000;
const identity = { uid: 'alice', auth_time: time / 1000, firebase: { sign_in_provider: 'password' } };

test('deletion requires a real account and recent authentication, not a fresh token alone', () => {
  for (const invalid of [null, { ...identity, auth_time: undefined }, { ...identity, auth_time: time / 1000 - 301 },
    { ...identity, auth_time: time / 1000 + 100 }, { ...identity, firebase: { sign_in_provider: 'anonymous' } }]) {
    assert.throws(() => requireRecentIdentity(invalid, time));
  }
  assert.doesNotThrow(() => requireRecentIdentity(identity, time));
});

test('cleanup removes authored data and descendants, maintains other posts, deletes Auth last', async () => {
  const db = store();
  for (const [path, value] of Object.entries({
    'forum_posts/owned': { uid: 'alice' },
    'forum_posts/owned/comments/bob': { uid: 'bob' },
    'forum_posts/other': { uid: 'bob', likedBy: ['alice', 'bob'], likes: 2, commentCount: 2 },
    'forum_posts/other/comments/alice': { uid: 'alice' },
    'forum_posts/other/comments/bob': { uid: 'bob' },
    'forum_posts/missing/comments/orphan': { uid: 'alice' },
    'reward_accounts/alice': { coins: 100 },
    'reward_accounts/alice/redemptions/pass': { coins: 30 },
    'reward_accounts/bob': { coins: 200 },
    'reward_sessions/session': { uid: 'alice' },
    'reward_receipts/receipt': { uid: 'alice' },
    'users/alice/saved/movie': { id: 1 },
    'forum_members/alice': { termsVersion: 1 },
    'forum_members/alice/blocked/bob': { uid: 'bob' },
    'forum_members/bob/blocked/alice': { uid: 'alice' },
    'forum_reports/authored': { reporterUid: 'alice', targetUid: 'bob' },
    'forum_reports/targeted': { reporterUid: 'bob', targetUid: 'alice' },
    'forum_reports/reviewed': { reporterUid: 'bob', targetUid: 'charlie', reviewedBy: 'alice', status: 'dismissed' },
  })) db.data.set(path, value);
  let deleted = 0;
  const service = createAccountDeletion({ db, now: () => time, auth: { deleteUser: async (uid) => {
    assert.equal(uid, 'alice');
    assert.equal(db.data.has('reward_accounts/alice'), false);
    assert.equal(db.data.has('forum_posts/other/comments/alice'), false);
    deleted++;
  } } });
  assert.deepEqual(await service.request(identity), { status: 'complete' });
  assert.equal(deleted, 1);
  assert.deepEqual(db.data.get('forum_posts/other'), { uid: 'bob', likedBy: ['bob'], likes: 1, commentCount: 1 });
  assert.equal(db.data.has('forum_posts/other/comments/bob'), true);
  assert.equal(db.data.has('forum_posts/owned/comments/bob'), false);
  assert.equal(db.data.has('forum_posts/missing/comments/orphan'), false);
  assert.equal(db.data.has('users/alice/saved/movie'), false);
  assert.equal(db.data.has('forum_members/alice'), false);
  assert.equal(db.data.has('forum_members/alice/blocked/bob'), false);
  assert.equal(db.data.has('forum_members/bob/blocked/alice'), false);
  assert.equal(db.data.has('forum_reports/authored'), false);
  assert.equal(db.data.has('forum_reports/targeted'), false);
  assert.equal(db.data.get('forum_reports/reviewed').reviewedBy, undefined);
  assert.equal(db.data.get('forum_reports/reviewed').status, 'dismissed');
  assert.deepEqual(db.data.get('reward_accounts/bob'), { coins: 200 });
  await service.request(identity);
  assert.equal(deleted, 1);
});

test('failed cleanup stays durable; worker retries; completed fences expire after seven days', async () => {
  const db = store();
  db.data.set('reward_sessions/session', { uid: 'alice' });
  let fail = true;
  const original = db.recursiveDelete;
  db.recursiveDelete = async (ref) => { if (fail) throw new Error('offline'); await original(ref); };
  let deleted = 0;
  let now = time;
  const service = createAccountDeletion({ db, now: () => now, auth: { deleteUser: async () => { deleted++; } } });
  assert.deepEqual(await service.request(identity), { status: 'pending' });
  assert.equal(deleted, 0);
  fail = false;
  await service.retryPending();
  assert.equal(deleted, 1);
  assert.equal(db.data.get('account_deletions/alice').status, 'complete');
  now += 7 * 86400000 + 1;
  await service.retryPending();
  assert.equal(db.data.has('account_deletions/alice'), false);
});

test('public page is reachable; unauthenticated deletion is rejected; rollout defaults off', async (t) => {
  const express = require('express');
  const app = express();
  let privilegedAccess = false;
  registerAccountDeletionRoutes(app, { page: '<h1>Delete Movie Hub account</h1>', enabled: () => false,
    firebaseAuth: () => { privilegedAccess = true; },
    authenticate: (req, res, next) => {
      if (!req.header('authorization')) return res.sendStatus(401);
      req.firebaseUser = identity;
      next();
    } });
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const page = await fetch(`${base}/delete-account`);
  assert.equal(page.status, 200);
  assert.match(page.headers.get('content-security-policy'), /frame-ancestors 'none'/);
  assert.match(page.headers.get('content-security-policy'), /script-src 'self' https:\/\/www\.gstatic\.com https:\/\/apis\.google\.com;/);
  assert.match(page.headers.get('content-security-policy'), /connect-src[^;]+https:\/\/apis\.google\.com;/);
  assert.equal((await fetch(`${base}/api/account`, { method: 'DELETE' })).status, 401);
  assert.equal((await fetch(`${base}/api/account`, { method: 'DELETE', headers: { authorization: 'Bearer token' } })).status, 503);
  assert.equal(privilegedAccess, false);
});
