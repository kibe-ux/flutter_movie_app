const { getFirestore } = require('firebase-admin/firestore');
const { randomUUID } = require('node:crypto');

const RETENTION_MS = 7 * 86400000;
class DeletionError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function requireRecentIdentity(identity, now = Date.now()) {
  if (!identity?.uid || identity.firebase?.sign_in_provider === 'anonymous') {
    throw new DeletionError(403, 'Sign in with your account to request deletion.');
  }
  if (!Number.isFinite(identity.auth_time) || identity.auth_time * 1000 > now + 60000 ||
      now - identity.auth_time * 1000 > 5 * 60000) {
    throw new DeletionError(401, 'Please verify your identity again before deleting your account.');
  }
}

// A durable job doubles as a write fence. Keep completed fences for seven days
// so an old Firebase token cannot recreate data after Auth deletion.
function createAccountDeletion({ db, auth, now = Date.now }) {
  const jobs = db.collection('account_deletions');
  async function drain(query, action) {
    while (true) {
      const page = await query.limit(100).get();
      if (page.empty) return;
      for (const doc of page.docs) await action(doc);
    }
  }
  async function process(uid) {
    const job = jobs.doc(uid);
    const lease = randomUUID();
    const acquired = await db.runTransaction(async (tx) => {
      const data = (await tx.get(job)).data();
      if (!data || data.status === 'complete' || data.leaseUntil > now()) return false;
      tx.update(job, { lease, leaseUntil: now() + 60000 });
      return true;
    });
    if (!acquired) return false;
    // Renew before every bounded step. Losing a lease stops this worker.
    async function renew() {
      await db.runTransaction(async (tx) => {
        const data = (await tx.get(job)).data();
        if (data?.lease !== lease) throw new Error('Deletion lease changed');
        tx.update(job, { leaseUntil: now() + 60000 });
      });
    }
    try {
      await drain(db.collection('forum_posts').where('uid', '==', uid), async (doc) => {
        await renew();
        await db.recursiveDelete(doc.ref);
      });
      // Replies on somebody else's discussion must be removed too. Delete and
      // decrement together so retries cannot decrement the count twice.
      await drain(db.collectionGroup('comments').where('uid', '==', uid), async (doc) => {
        await renew();
        if (doc.ref.parent.parent?.parent.id !== 'forum_posts') return doc.ref.delete();
        await db.runTransaction(async (tx) => {
          const reply = await tx.get(doc.ref);
          const parent = doc.ref.parent.parent;
          const post = await tx.get(parent);
          if (!reply.exists) return;
          tx.delete(doc.ref);
          if (post.exists) tx.update(parent, { commentCount: Math.max(0, (post.data().commentCount || 0) - 1) });
        });
      });
      await drain(db.collection('forum_posts').where('likedBy', 'array-contains', uid), async (doc) => {
        await renew();
        await db.runTransaction(async (tx) => {
          const snapshot = await tx.get(doc.ref);
          if (!snapshot.exists) return;
          const likedBy = (snapshot.data().likedBy || []).filter((id) => id !== uid);
          tx.update(doc.ref, { likedBy, likes: likedBy.length });
        });
      });
      for (const name of ['reward_sessions', 'reward_receipts']) {
        await drain(db.collection(name).where('uid', '==', uid), async (doc) => {
          await renew();
          await db.recursiveDelete(doc.ref);
        });
      }
      for (const field of ['reporterUid', 'targetUid']) {
        await drain(db.collection('forum_reports').where(field, '==', uid), async (doc) => {
          await renew();
          await db.recursiveDelete(doc.ref);
        });
      }
      await drain(db.collection('forum_reports').where('reviewedBy', '==', uid), async (doc) => {
        await renew();
        await db.runTransaction(async (tx) => {
          const snapshot = await tx.get(doc.ref);
          if (!snapshot.exists) return;
          const data = snapshot.data();
          delete data.reviewedBy;
          tx.set(doc.ref, data);
        });
      });
      await drain(db.collectionGroup('blocked').where('uid', '==', uid), async (doc) => {
        await renew();
        await db.recursiveDelete(doc.ref);
      });
      for (const name of ['reward_accounts', 'users', 'forum_members']) {
        await renew();
        await db.recursiveDelete(db.collection(name).doc(uid));
      }
      await renew();
      try { await auth.deleteUser(uid); }
      catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
      await db.runTransaction(async (tx) => {
        const data = (await tx.get(job)).data();
        if (data?.lease !== lease) throw new Error('Deletion lease changed');
        tx.set(job, { status: 'complete', completedAt: now(), purgeAfter: now() + RETENTION_MS });
      });
      return true;
    } catch (error) {
      await db.runTransaction(async (tx) => {
        const data = (await tx.get(job)).data();
        if (data?.lease === lease) tx.update(job, { leaseUntil: 0 });
      });
      throw error;
    }
  }
  return {
    async request(identity) {
      requireRecentIdentity(identity, now());
      const ref = jobs.doc(identity.uid);
      await db.runTransaction(async (tx) => {
        if (!(await tx.get(ref)).exists) {
          tx.set(ref, { status: 'pending', requestedAt: now(), leaseUntil: 0 });
        }
      });
      try { await process(identity.uid); } catch (_) { /* Durable worker retries. */ }
      return { status: (await ref.get()).data()?.status || 'pending' };
    },
    process,
    async retryPending() {
      let failures = 0;
      let completedJobs = 0;
      let jobsSeen = 0;
      let oldestPendingAgeMs = 0;
      let cursor;
      // Traverse the queue even if an early job fails repeatedly. Otherwise the
      // same first hundred failures can starve all later requests forever.
      while (true) {
        let query = jobs.where('status', '==', 'pending').limit(100);
        if (cursor) query = query.startAfter(cursor);
        const pending = await query.get();
        if (pending.empty) break;
        cursor = pending.docs.at(-1);
        for (const doc of pending.docs) {
          jobsSeen++;
          try {
            if (await process(doc.id)) completedJobs++;
            else oldestPendingAgeMs = Math.max(oldestPendingAgeMs, now() - (doc.data().requestedAt || now()));
          } catch (_) { failures++; }
        }
      }
      let purgedFences = 0;
      await drain(jobs.where('purgeAfter', '<=', now()), async (doc) => { await doc.ref.delete(); purgedFences++; });
      if (failures) throw new Error(`${failures} account deletion jobs need another retry`);
      return { jobsSeen, completedJobs, purgedFences, oldestPendingAgeMs };
    },
  };
}

function registerAccountDeletionRoutes(app, { authenticate, firebaseAuth, page,
  enabled = () => process.env.ACCOUNT_DELETION_ENABLED === 'true' }) {
  app.get('/delete-account', (req, res) => {
    res.set('Cache-Control', 'no-store');
    res.set('Referrer-Policy', 'no-referrer');
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('Content-Security-Policy', "default-src 'none'; script-src 'self' https://www.gstatic.com https://apis.google.com; style-src 'unsafe-inline'; connect-src 'self' https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://*.googleapis.com https://apis.google.com; frame-src https://*.firebaseapp.com https://accounts.google.com; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
    const body = enabled() ? page : page.replace('<main>', '<main><p role="note">Automatic deletion is being prepared. You can verify sign-in below, or email privacymoviehub@gmail.com for help. No deletion will start until this service is enabled.</p>');
    res.type('html').send(body);
  });
  app.delete('/api/account', authenticate, async (req, res) => {
    res.set('Cache-Control', 'no-store');
    try {
      if (!enabled()) throw new DeletionError(503, 'Account deletion is being prepared. Please try again later.');
      requireRecentIdentity(req.firebaseUser);
      const auth = firebaseAuth();
      const result = await createAccountDeletion({ db: getFirestore(auth.app), auth }).request(req.firebaseUser);
      res.status(result.status === 'complete' ? 200 : 202).json(result);
    } catch (error) {
      res.status(error instanceof DeletionError ? error.status : 503).json({
        error: error instanceof DeletionError ? error.message : 'Deletion could not be requested. Please try again.',
      });
    }
  });
}

module.exports = { createAccountDeletion, requireRecentIdentity, registerAccountDeletionRoutes, DeletionError };
