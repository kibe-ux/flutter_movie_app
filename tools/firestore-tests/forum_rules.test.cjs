const { before, beforeEach, after, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { requireReadyIndexes } = require('../../scripts/firestore_index_readiness.cjs');
const { initializeTestEnvironment, assertSucceeds, assertFails,
  doc, collection, getDoc, getDocs, query, where, orderBy, setDoc, updateDoc, deleteDoc,
  writeBatch, serverTimestamp, Timestamp, increment, setLogLevel } = require('./emulator_rest.cjs');

// This suite can only talk to the local emulator and a demo project. It neither
// consumes production user identities nor reads/writes production Firestore.
const projectId = 'demo-moviehub-security';
const moderator = () => env.authenticatedContext('mod', { moderator: true, firebase: { sign_in_provider: 'password' } }).firestore();
let env;
const member = (uid, provider = 'password') => env.authenticatedContext(uid,
  { firebase: { sign_in_provider: provider } }).firestore();
const post = (uid = 'alice', changes = {}) => ({ uid, author: uid, photoURL: null,
  title: 'Movie night', content: 'A film recommendation', category: 'Discussion',
  timestamp: serverTimestamp(), likes: 0, likedBy: [], commentCount: 0,
  lastCommentId: null, deleting: false, ...changes });
const reply = (uid = 'bob', changes = {}) => ({ uid, author: uid, photoURL: null,
  content: 'A reply', timestamp: serverTimestamp(), ...changes });
async function seed(entries) {
  await env.withSecurityRulesDisabled(async (context) => {
    for (const [location, data] of Object.entries(entries)) await setDoc(doc(context.firestore(), location), data);
  });
}
async function seedPost(changes = {}) { await seed({ 'forum_posts/p': post('alice', changes) }); }
function addReply(db, id = 'r', changes = {}, parentChanges = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'forum_posts/p/comments/' + id), reply('bob', changes));
  batch.update(doc(db, 'forum_posts/p'), { commentCount: increment(1), lastCommentId: id, ...parentChanges });
  return batch.commit();
}
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8085', 'Run through the isolated emulator configuration.');
  setLogLevel('silent');
  env = await initializeTestEnvironment({ projectId, firestore: { host: '127.0.0.1', port: 8085,
    rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8') } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed(Object.fromEntries(['alice', 'bob', 'charlie'].map((uid) =>
    ['forum_members/' + uid, { termsVersion: 1, acceptedAt: serverTimestamp() }])));
});
after(async () => { if (env) await env.cleanup(); });

test('production publication gate accepts only complete READY index verification', () => {
  const readyFields = [{ indexConfig: { indexes: [{ state: 'READY' }] } }];
  assert.doesNotThrow(() => requireReadyIndexes([{ state: 'READY' }], readyFields, 1, 1));
  for (const state of ['CREATING', 'NEEDS_REPAIR', undefined]) {
    assert.throws(() => requireReadyIndexes([{ state }], readyFields, 1, 1));
    assert.throws(() => requireReadyIndexes([{ state: 'READY' }], [{ indexConfig: { indexes: [{ state }] } }], 1, 1));
  }
});
test('production publication gate rejects missing verification or missing field indexes', () => {
  assert.throws(() => requireReadyIndexes([], [], 1, 1));
  assert.throws(() => requireReadyIndexes([{ state: 'READY' }], [{}], 1, 1));
  assert.throws(() => requireReadyIndexes([{ state: 'READY' }], [{ indexConfig: { indexes: [] } }], 1, 1));
});

test('guests can read public posts/replies and feed queries', async () => {
  await seedPost();
  await seed({ 'forum_posts/p/comments/r': reply() });
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(guest, 'forum_posts/p')));
  await assertSucceeds(getDoc(doc(guest, 'forum_posts/p/comments/r')));
  await assertSucceeds(getDocs(query(collection(guest, 'forum_posts'), where('category', '==', 'Discussion'), orderBy('timestamp', 'desc'))));
});
test('members create validated discussions; guests and anonymous accounts cannot write', async () => {
  await assertSucceeds(setDoc(doc(member('alice'), 'forum_posts/p'), post()));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'forum_posts/guest'), post()));
  await assertFails(setDoc(doc(member('anon', 'anonymous'), 'forum_posts/anonymous'), post('anon')));
});
test('post creation rejects spoofed UID, extra fields, invalid content/categories/timestamps and initial counters', async () => {
  const alice = member('alice');
  const variants = [{ uid: 'bob' }, { admin: true }, { title: '' }, { title: 'x'.repeat(101) },
    { content: '' }, { content: 'x'.repeat(1001) }, { category: 'Unknown' },
    { timestamp: Timestamp.fromMillis(1) }, { likes: 10 }, { likedBy: ['bob'] },
    { commentCount: 1 }, { lastCommentId: 'r' }, { deleting: true }, { author: 123 },
    { photoURL: 'javascript:alert(1)' }];
  for (const [i, changes] of variants.entries()) await assertFails(setDoc(doc(alice, 'forum_posts/invalid' + i), post('alice', changes)));
});
test('post ownership, author, content and timestamp remain immutable', async () => {
  await seedPost();
  for (const uid of ['alice', 'bob']) {
    for (const changes of [{ uid: 'bob' }, { author: 'Someone else' }, { content: 'Replaced' },
      { timestamp: serverTimestamp() }, { extra: true }]) {
      await assertFails(updateDoc(doc(member(uid), 'forum_posts/p'), changes));
    }
  }
});
test('a member can add and remove only their own like, with an exact counter', async () => {
  await seedPost({ likedBy: ['alice'], likes: 1 });
  const ref = doc(member('bob'), 'forum_posts/p');
  await assertSucceeds(updateDoc(ref, { likedBy: ['alice', 'bob'], likes: 2 }));
  await assertSucceeds(updateDoc(ref, { likedBy: ['alice'], likes: 1 }));
});
test('likes reject impersonation, removal of other likes, duplicates and forged counters', async () => {
  await seedPost({ likedBy: ['alice'], likes: 1 });
  const ref = doc(member('bob'), 'forum_posts/p');
  for (const changes of [{ likedBy: ['alice', 'charlie'], likes: 2 }, { likedBy: [], likes: 0 },
    { likedBy: ['bob'], likes: 1 }, { likedBy: ['alice', 'bob', 'bob'], likes: 3 },
    { likedBy: ['alice', 'bob'], likes: 900 }, { likes: 900 }, { likedBy: 'bob', likes: 1 }]) {
    await assertFails(updateDoc(ref, changes));
  }
});
test('reply creation and parent count update succeed only together', async () => {
  await seedPost();
  const bob = member('bob');
  await assertSucceeds(addReply(bob));
  assert.equal((await getDoc(doc(bob, 'forum_posts/p'))).data().commentCount, 1);
  await assertFails(setDoc(doc(bob, 'forum_posts/p/comments/alone'), reply()));
  await assertFails(updateDoc(doc(bob, 'forum_posts/p'), { commentCount: 2, lastCommentId: 'phantom' }));
});
test('reply batch rejects forged counts, mismatched IDs, another author and body changes', async () => {
  await seedPost();
  const bob = member('bob');
  await assertFails(addReply(bob, 'r', {}, { commentCount: 50 }));
  await assertFails(addReply(bob, 'r', {}, { lastCommentId: 'different' }));
  await assertFails(addReply(bob, 'r', { uid: 'alice' }));
  await assertFails(addReply(bob, 'r', {}, { content: 'Forged post content' }));
  for (const changes of [{ content: '' }, { content: 'x'.repeat(1001) }, { role: 'moderator' },
    { timestamp: Timestamp.fromMillis(1) }, { author: false }, { photoURL: 'file:///secret' }]) {
    await assertFails(addReply(bob, 'r', changes));
  }
});
test('an existing reply cannot be replayed to increase the counter', async () => {
  await seedPost();
  const bob = member('bob');
  await assertSucceeds(addReply(bob));
  await assertFails(updateDoc(doc(bob, 'forum_posts/p'), { commentCount: 2, lastCommentId: 'r' }));
  await assertFails(addReply(bob));
});
test('two replies cannot share a single parent count increment', async () => {
  await seedPost();
  const bob = member('bob');
  const batch = writeBatch(bob);
  batch.set(doc(bob, 'forum_posts/p/comments/r1'), reply());
  batch.set(doc(bob, 'forum_posts/p/comments/r2'), reply());
  batch.update(doc(bob, 'forum_posts/p'), { commentCount: 1, lastCommentId: 'r1' });
  await assertFails(batch.commit());
});
test('missing parent posts cannot receive replies', async () => {
  const bob = member('bob');
  await assertFails(setDoc(doc(bob, 'forum_posts/missing/comments/r'), reply()));
  await assertFails(addReply(bob));
});
test('replies cannot be edited or deleted outside owner cleanup', async () => {
  await seedPost({ commentCount: 1, lastCommentId: 'r' });
  await seed({ 'forum_posts/p/comments/r': reply() });
  for (const uid of ['alice', 'bob', 'charlie']) {
    await assertFails(updateDoc(doc(member(uid), 'forum_posts/p/comments/r'), { content: 'Changed' }));
    await assertFails(deleteDoc(doc(member(uid), 'forum_posts/p/comments/r')));
  }
});
test('only owners can begin deletion; deleting posts cannot be reopened, liked or replied to', async () => {
  await seedPost();
  const alice = member('alice');
  const bob = member('bob');
  await assertFails(updateDoc(doc(bob, 'forum_posts/p'), { deleting: true }));
  await assertFails(deleteDoc(doc(alice, 'forum_posts/p')));
  await assertSucceeds(updateDoc(doc(alice, 'forum_posts/p'), { deleting: true }));
  await assertFails(updateDoc(doc(alice, 'forum_posts/p'), { deleting: false }));
  await assertFails(addReply(bob));
  await assertFails(updateDoc(doc(bob, 'forum_posts/p'), { likedBy: ['bob'], likes: 1 }));
  await assertFails(deleteDoc(doc(bob, 'forum_posts/p')));
});
test('owners can remove replies then delete a marked discussion', async () => {
  await seedPost({ commentCount: 1, lastCommentId: 'r' });
  await seed({ 'forum_posts/p/comments/r': reply() });
  const alice = member('alice');
  await assertSucceeds(updateDoc(doc(alice, 'forum_posts/p'), { deleting: true }));
  await assertFails(deleteDoc(doc(member('bob'), 'forum_posts/p/comments/r')));
  await assertSucceeds(deleteDoc(doc(alice, 'forum_posts/p/comments/r')));
  await assertSucceeds(deleteDoc(doc(alice, 'forum_posts/p')));
});
test('account deletion fences deny all writes by the deleting account and replies/likes on its posts', async () => {
  await seedPost();
  await seed({ 'account_deletions/alice': { status: 'pending' } });
  const alice = member('alice');
  const bob = member('bob');
  await assertFails(setDoc(doc(alice, 'forum_posts/new'), post()));
  await assertFails(updateDoc(doc(alice, 'forum_posts/p'), { deleting: true }));
  await assertFails(updateDoc(doc(alice, 'forum_posts/p'), { likedBy: ['alice'], likes: 1 }));
  await assertFails(addReply(bob));
  await assertFails(updateDoc(doc(bob, 'forum_posts/p'), { likedBy: ['bob'], likes: 1 }));
  await seed({ 'account_deletions/bob': { status: 'complete' } });
  await assertFails(setDoc(doc(bob, 'forum_posts/new'), post('bob')));
});
test('a deleting member cannot reply on an otherwise active account post', async () => {
  await seedPost();
  await seed({ 'account_deletions/bob': { status: 'pending' } });
  await assertFails(addReply(member('bob')));
});
test('private profiles, deletion jobs, rewards and unknown collections deny all client access', async () => {
  const locations = ['users/alice', 'users/alice/saved/movie', 'account_deletions/alice',
    'reward_accounts/alice', 'reward_accounts/alice/redemptions/pass', 'reward_sessions/session',
    'reward_receipts/receipt', 'unknown/document'];
  await seed(Object.fromEntries(locations.map((location) => [location, { secret: true }])));
  for (const db of [member('alice'), member('bob'), env.unauthenticatedContext().firestore()]) {
    for (const location of locations) {
      const ref = doc(db, location);
      await assertFails(getDoc(ref));
      await assertFails(setDoc(ref, { changed: true }));
      await assertFails(deleteDoc(ref));
    }
  }
});

const report = (changes = {}) => ({ reporterUid: 'bob', targetUid: 'alice', targetType: 'post',
  postId: 'p', commentId: null, reason: 'Spam or scam', details: 'Please review',
  timestamp: serverTimestamp(), status: 'open', ...changes });
const removedPost = () => ({ removed: true, deleting: true, title: 'Discussion removed',
  content: 'This discussion was removed for violating community rules.', author: 'Member',
  photoURL: null, moderatedAt: serverTimestamp() });

test('community terms acceptance is required and cannot grant moderator privileges', async () => {
  const dave = member('dave');
  await assertFails(setDoc(doc(dave, 'forum_posts/new'), post('dave')));
  await assertFails(setDoc(doc(dave, 'forum_members/dave'), { termsVersion: 1, acceptedAt: serverTimestamp(), moderator: true }));
  await assertSucceeds(setDoc(doc(dave, 'forum_members/dave'), { termsVersion: 1, acceptedAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(dave, 'forum_posts/new'), post('dave')));
  await assertFails(getDoc(doc(member('bob'), 'forum_members/dave')));
});
test('members report actual content, but reports remain private and immutable to reporters', async () => {
  await seedPost();
  const bob = member('bob');
  const ref = doc(bob, 'forum_reports/bob:post:p:post');
  await assertSucceeds(setDoc(ref, report()));
  await assertFails(getDoc(ref));
  await assertFails(setDoc(ref, report()));
  await assertFails(updateDoc(ref, { status: 'dismissed' }));
  await assertSucceeds(getDoc(doc(moderator(), 'forum_reports/bob:post:p:post')));
  await assertSucceeds(getDocs(query(collection(moderator(), 'forum_reports'), where('status', '==', 'open'))));
});
test('reports reject forged targets, reporters, statuses, details and IDs', async () => {
  await seedPost();
  const bob = member('bob');
  for (const changes of [{ reporterUid: 'alice' }, { targetUid: 'charlie' }, { status: 'removed' },
    { reason: 'unrecognized' }, { details: 'x'.repeat(1001) }, { postId: 'missing' },
    { postId: 'p/comments/r' }, { moderator: true }]) {
    await assertFails(setDoc(doc(bob, 'forum_reports/bob:post:p:post'), report(changes)));
  }
  await assertFails(setDoc(doc(bob, 'forum_reports/random'), report()));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'forum_reports/bob:post:p:post'), report()));
});
test('reply and user reports remain separately labeled and target the source author', async () => {
  await seedPost();
  await seed({ 'forum_posts/p/comments/r': reply('alice') });
  const bob = member('bob');
  await assertSucceeds(setDoc(doc(bob, 'forum_reports/bob:comment:p:r'), report({ targetType: 'comment', commentId: 'r' })));
  await assertSucceeds(setDoc(doc(bob, 'forum_reports/bob:user:p:r'), report({ targetType: 'user', commentId: 'r' })));
});
test('block lists are owner-private, forbid self-blocking and enforce both interaction directions', async () => {
  await seedPost();
  await seed({ 'forum_posts/bobpost': post('bob') });
  const alice = member('alice'), bob = member('bob');
  const block = doc(alice, 'forum_members/alice/blocked/bob');
  await assertSucceeds(setDoc(block, { uid: 'bob', author: 'Bob', timestamp: serverTimestamp() }));
  await assertSucceeds(getDoc(block));
  await assertFails(getDoc(doc(bob, 'forum_members/alice/blocked/bob')));
  await assertFails(setDoc(doc(alice, 'forum_members/alice/blocked/alice'), { uid: 'alice', author: 'Alice', timestamp: serverTimestamp() }));
  await assertFails(addReply(bob));
  await assertFails(updateDoc(doc(bob, 'forum_posts/p'), { likedBy: ['bob'], likes: 1 }));
  await assertFails(updateDoc(doc(alice, 'forum_posts/bobpost'), { likedBy: ['alice'], likes: 1 }));
  await assertSucceeds(deleteDoc(block));
  await assertSucceeds(addReply(bob));
});
test('only trusted moderators can replace abusive content with fixed removal notices', async () => {
  await seedPost({ content: 'Offending text' });
  await assertFails(updateDoc(doc(member('bob'), 'forum_posts/p'), removedPost()));
  await assertSucceeds(updateDoc(doc(moderator(), 'forum_posts/p'), removedPost()));
  const data = (await getDoc(doc(member('bob'), 'forum_posts/p'))).data();
  assert.equal(data.content, 'This discussion was removed for violating community rules.');
  await assertFails(updateDoc(doc(moderator(), 'forum_posts/p'), { content: 'Arbitrary replacement' }));
  await assertFails(addReply(member('bob')));
});
test('removing a discussion closes public access to its replies while moderators can review them', async () => {
  await seedPost();
  await seed({ 'forum_posts/p/comments/r': reply() });
  await assertSucceeds(updateDoc(doc(moderator(), 'forum_posts/p'), removedPost()));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'forum_posts/p/comments/r')));
  await assertSucceeds(getDoc(doc(moderator(), 'forum_posts/p/comments/r')));
});
test('moderator report decisions must preserve report metadata and removal must actually occur', async () => {
  await seedPost();
  await seed({ 'forum_reports/bob:post:p:post': report() });
  const mod = moderator();
  const ref = doc(mod, 'forum_reports/bob:post:p:post');
  const decision = { status: 'removed', reviewedBy: 'mod', reviewedAt: serverTimestamp() };
  await assertFails(updateDoc(ref, decision));
  await assertFails(updateDoc(ref, { ...decision, status: 'dismissed', reporterUid: 'charlie' }));
  const batch = writeBatch(mod);
  batch.update(doc(mod, 'forum_posts/p'), removedPost());
  batch.update(ref, decision);
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(ref, { status: 'open' }));
});
test('moderators can remove individual replies and dismiss reports without touching content', async () => {
  await seedPost();
  await seed({ 'forum_posts/p/comments/r': reply(), 'forum_reports/bob:post:p:post': report() });
  const mod = moderator();
  await assertSucceeds(updateDoc(doc(mod, 'forum_posts/p/comments/r'), {
    removed: true, content: 'This reply was removed for violating community rules.', author: 'Member',
    photoURL: null, moderatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(mod, 'forum_reports/bob:post:p:post'), {
    status: 'dismissed', reviewedBy: 'mod', reviewedAt: serverTimestamp(),
  }));
});
test('deletion fences stop reporting, blocking and moderator actions', async () => {
  await seedPost();
  await seed({ 'account_deletions/bob': { status: 'pending' }, 'account_deletions/mod': { status: 'pending' } });
  await assertFails(setDoc(doc(member('bob'), 'forum_reports/bob:post:p:post'), report()));
  await assertFails(setDoc(doc(member('bob'), 'forum_members/bob/blocked/alice'), { uid: 'alice', author: 'Alice', timestamp: serverTimestamp() }));
  await assertFails(updateDoc(doc(moderator(), 'forum_posts/p'), removedPost()));
});

test('deleting targets cannot receive new reports or block records during cleanup', async () => {
  await seedPost();
  await seed({ 'account_deletions/alice': { status: 'pending' } });
  const bob = member('bob');
  await assertFails(setDoc(doc(bob, 'forum_reports/bob:post:p:post'), report()));
  await assertFails(setDoc(doc(bob, 'forum_members/bob/blocked/alice'), {
    uid: 'alice', author: 'Alice', timestamp: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(bob, 'forum_members/bob/blocked/missing'), {
    uid: 'missing', author: 'Missing', timestamp: serverTimestamp(),
  }));
});
