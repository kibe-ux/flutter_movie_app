const test = require('node:test');
const assert = require('node:assert/strict');
const { createWambeshaMetadataCache, metadataTtl } = require('../wambesha_metadata_cache');

function store() {
  const rows = new Map();
  return { rows,
    async read(key) { return rows.get(key); },
    async acquire(key, owner, now) {
      if (rows.get(key)?.retry_at > now) return false;
      return true;
    },
    async publish(key, owner, body, fresh_until) { rows.set(key, { body, fresh_until }); },
    async release(key, owner, retry_at) { rows.set(key, { retry_at }); },
  };
}

test('delivery metadata never inherits title cache lifetimes', async () => {
  const memory = store();
  const cache = createWambeshaMetadataCache({ store: memory });
  const response = await cache.get('title', metadataTtl('/titles/mv_ONE'), async () => ({
    id: 'mv_ONE', title: 'Movie', sources: ['signed-secret'], links: ['signed-secret'],
    nested: { subtitles: ['signed-secret'], magnets: ['private-evidence'] },
    trailer: { url: 'https://www.youtube.com/watch?v=test' },
  }));
  assert.doesNotMatch(JSON.stringify(response), /signed-secret|private-evidence/);
  assert.equal(response.body.trailer.url, 'https://www.youtube.com/watch?v=test');
});

test('expired metadata refreshes; failures and database outages never bypass the cache lease', async () => {
  let time = 1000, calls = 0;
  const memory = store();
  const cache = createWambeshaMetadataCache({ store: memory, now: () => time, pause: async () => {} });
  const provider = async () => { calls++; return { id: 'mv_ONE' }; };
  await cache.get('title', 1000, provider);
  assert.equal((await cache.get('title', 1000, provider)).hit, true);
  time += 1001;
  assert.equal((await cache.get('title', 1000, provider)).hit, false);
  assert.equal(calls, 2);
  await assert.rejects(cache.get('failed', 1000, async () => { throw Error('provider failed'); }));
  await assert.rejects(cache.get('failed', 1000, provider));
  assert.equal(calls, 2, 'cooldown never bypasses the lease');
  const offline = createWambeshaMetadataCache({ store: { read: async () => { throw Error('offline'); } } });
  await assert.rejects(offline.get('title', 1000, provider));
  assert.equal(calls, 2);
});
