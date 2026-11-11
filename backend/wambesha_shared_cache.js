const { randomUUID } = require('node:crypto');
const { setTimeout: sleep } = require('node:timers/promises');
const { EXPIRY_MARGIN_MS, sourceLinks } = require('./wambesha_resources');

// Enable only after signed-link reuse across users/egress addresses is verified.
// No stale source links are served, and a store failure never bypasses a lease.
function createSharedSourceCache({ store, now = Date.now, pause = sleep }) {
  return {
    async get(key, fetchSource) {
      const saved = await store.read(key);
      if (saved?.body && saved.fresh_until > now()) return { body: saved.body, cache: 'SHARED_HIT' };
      if (saved?.retry_at > now()) throw new Error('Source refresh is cooling down.');
      const owner = randomUUID();
      if (!await store.acquire(key, owner, now(), 30000)) {
        // Fixed iterations keep waiting bounded even with an injected clock.
        for (let attempt = 0; attempt < 64; attempt++) {
          await pause(250);
          const row = await store.read(key);
          if (row?.body && row.fresh_until > now()) return { body: row.body, cache: 'SHARED_COALESCED' };
          if (!row || row.retry_at > now() || row.lease_until <= now()) break;
        }
        throw new Error('Source refresh is in progress.');
      }
      try {
        const body = await fetchSource();
        const links = sourceLinks(body);
        const signedLinks = links.filter(link => link.hosted !== 'youtube');
        let until = now() + (links.length ? 300000 : 30000);
        // Unknown-expiry links cannot enter persistent cross-user storage.
        const knownExpiry = signedLinks.every(source =>
          typeof source.expires_at === 'string' && Number.isFinite(Date.parse(source.expires_at)));
        if (!knownExpiry) {
          await store.release(key, owner, now() + 1000);
          return { body, cache: 'UNCACHEABLE' };
        }
        for (const source of links) {
          if (source.expires_at) until = Math.min(until, Date.parse(source.expires_at) - EXPIRY_MARGIN_MS);
        }
        if (until <= now()) throw new Error('Source expired during retrieval.');
        await store.publish(key, owner, body, until, until);
        return { body, cache: 'MISS' };
      } catch (error) {
        await store.release(key, owner, now() + 15000).catch(() => {});
        throw error;
      }
    },
  };
}

module.exports = { createSharedSourceCache };
