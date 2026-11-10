const test = require('node:test');
const assert = require('node:assert/strict');
const { createSharedSourceCache } = require('../wambesha_shared_cache');

function memoryStore() {
  const rows = new Map();
  return {
    rows,
    async read(key) { return rows.get(key); },
    async acquire(key, owner, now, lease) {
      const row = rows.get(key);
      if (row && (row.lease_until > now || row.fresh_until > now || row.retry_at > now)) return false;
      rows.set(key, { ...row, owner, lease_until: now + lease });
      return true;
    },
    async publish(key, owner, body, fresh_until, stale_until) {
      assert.equal(rows.get(key).owner, owner);
      rows.set(key, { body, fresh_until, stale_until, lease_until: 0 });
    },
    async release(key, owner, retry_at) {
      assert.equal(rows.get(key).owner, owner);
      rows.set(key, { ...rows.get(key), lease_until: 0, retry_at });
    },
  };
}
const source = expiry => ({ sources: [{ url: 'https://example.test/signed', expires_at: new Date(expiry).toISOString() }] });

test('two instances coalesce and refresh before signed expiry', async () => {
  const store = memoryStore();
  let time = 1000000, calls = 0;
  const a = createSharedSourceCache({ store, now: () => time });
  const b = createSharedSourceCache({ store, now: () => time });
  const fetchSource = async () => {
    calls++;
    await new Promise(resolve => setTimeout(resolve, 10));
    return source(time + 60000);
  };
  const results = await Promise.all([a.get('key', fetchSource), b.get('key', fetchSource)]);
  assert.equal(calls, 1);
  assert.deepEqual(results.map(row => row.cache), ['MISS', 'SHARED_COALESCED']);
  assert.equal((await b.get('key', fetchSource)).cache, 'SHARED_HIT');
  time += 30000;
  assert.equal((await b.get('key', fetchSource)).cache, 'MISS');
  assert.equal(calls, 2);
});

test('unknown expiry is not persisted and store failures do not call provider', async () => {
  const store = memoryStore();
  const cache = createSharedSourceCache({ store, now: () => 1000 });
  const result = await cache.get('key', async () => ({ sources: [{ url: 'https://example.test' }] }));
  assert.equal(result.cache, 'UNCACHEABLE');
  assert.equal(store.rows.get('key').body, undefined);
  let called = false;
  const unavailable = createSharedSourceCache({ store: { read: async () => { throw Error('offline'); } } });
  await assert.rejects(unavailable.get('key', async () => { called = true; }));
  assert.equal(called, false);
});

test('failed refresh backs off without retrying or serving stale links', async () => {
  const store = memoryStore();
  let calls = 0;
  const cache = createSharedSourceCache({ store, now: () => 1000 });
  const fail = async () => { calls++; throw Error('provider failure'); };
  await assert.rejects(cache.get('key', fail));
  await assert.rejects(cache.get('key', fail));
  assert.equal(calls, 1);
});

test('different cache keys never share source responses', async () => {
  const store = memoryStore();
  const cache = createSharedSourceCache({ store, now: () => 1000 });
  let calls = 0;
  const fetchSource = async () => { calls++; return source(100000); };
  await cache.get('user-a:en:key-a', fetchSource);
  await cache.get('user-b:en:key-a', fetchSource);
  await cache.get('user-a:fr:key-a', fetchSource);
  assert.equal(calls, 3);
});
