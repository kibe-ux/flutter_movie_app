const { randomUUID } = require('node:crypto');
const { setTimeout: sleep } = require('node:timers/promises');

// Public metadata only. Source URLs never enter this cache or its 24-hour TTL.
function metadataTtl(path) {
  if (path === '/lookup' || path === '/genres') return 24 * 3600000;
  if (path === '/titles' || /^\/titles\/[^/]+$/.test(path)) return 6 * 3600000;
  if (/^\/titles\/[^/]+\/episodes$/.test(path)) return 3600000;
  return 0;
}

function createWambeshaMetadataCache({ store, now = Date.now, pause = sleep }) {
  return {
    async get(key, ttl, fetchMetadata) {
      const read = async () => {
        const row = await store.read(key);
        return row?.body && row.fresh_until > now() ? row.body : null;
      };
      const cached = await read();
      if (cached) return { body: cached, hit: true };
      const owner = randomUUID();
      if (!await store.acquire(key, owner, now(), 30000)) {
        for (let attempt = 0; attempt < 64; attempt++) {
          await pause(250);
          const body = await read();
          if (body) return { body, hit: true };
        }
        throw new Error('Metadata refresh is busy.');
      }
      try {
        const raw = await fetchMetadata();
        // Delivery fields have a different lifetime and must never inherit
        // a public metadata TTL, even if a provider adds them to a record.
        const blocked = new Set(['sources', 'links', 'subtitles', 'trailers', 'magnets', 'evidence', 'verification_spent']);
        const body = JSON.parse(JSON.stringify(raw, (name, value) => blocked.has(name) ? undefined : value));
        const until = now() + ttl;
        await store.publish(key, owner, body, until, until);
        return { body, hit: false };
      } catch (error) {
        await store.release(key, owner, now() + 15000).catch(() => {});
        throw error;
      }
    },
  };
}
module.exports = { metadataTtl, createWambeshaMetadataCache };
