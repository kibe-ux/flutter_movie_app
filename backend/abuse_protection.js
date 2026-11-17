const { createHash } = require('node:crypto');
const { getAppCheck } = require('firebase-admin/app-check');
const { createCatalogueStore } = require('./catalogue_store');
const { getRuntimeFirebaseAuth } = require('./firebase_runtime');

// Shared, atomic buckets. Never trust caller-supplied forwarding headers.
function createAbuseProtection({ database, store = createCatalogueStore(database), now = Date.now,
  verify = token => getAppCheck(getRuntimeFirebaseAuth().app).verifyToken(token),
  enforce = () => process.env.APP_CHECK_ENFORCED === 'true',
} = {}) {
  let cleanupAt = -Infinity;
  async function consume(key, limit, res) {
    try {
      const time = now();
      const retry = await store.consume(`abuse:${key}`, time, limit);
      if (retry) {
        res.set('Retry-After', String(retry)).status(429).json({ error: 'Too many requests. Please try again shortly.' });
        return false;
      }
      if (time - cleanupAt >= 60000) {
        cleanupAt = time;
        await store.cleanup(time);
      }
      return true;
    } catch {
      res.set('Retry-After', '15').status(503).json({ error: 'Request protection is temporarily unavailable.' });
      return false;
    }
  }
  return {
    async appCheck(req, res, next) {
      // SSV is authenticated by Google's signature; browser deletion uses Firebase reauthentication.
      if (!enforce() || req.path === '/rewards/ssv' || req.path === '/account' || req.path === '/download/stream') return next();
      const token = req.header('X-Firebase-AppCheck');
      if (!token) return res.status(401).json({ error: 'App verification is required.' });
      try { await verify(token); }
      catch { return res.status(401).json({ error: 'App verification failed.' }); }
      return next();
    },
    async ingress(req, res, next) {
      // Global ceiling also protects deployments whose adapter cannot supply a trusted client IP.
      if (!await consume('api:global', 3000, res)) return;
      const digest = createHash('sha256').update(req.socket.remoteAddress || 'unknown').digest('hex');
      if (!await consume(`network:${digest}`, 600, res)) return;
      return next();
    },
    async account(req, res, next) {
      const digest = createHash('sha256').update(req.firebaseUser.uid).digest('hex');
      const limit = req.path === '/api/account' ? 5 : 60;
      if (await consume(`account:${digest}:${req.path === '/api/account' ? 'deletion' : 'requests'}`, limit, res)) next();
    },
  };
}
module.exports = { createAbuseProtection };
