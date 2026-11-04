const test = require('node:test');
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const path = require('node:path');
const { createCatalogueStore } = require('../catalogue_store');
const { database } = require('../neon_database');

// Opt-in: uses an isolated, uniquely named schema, never the app's tables.
test('PostgreSQL cache budget: migration, concurrent writers, oversized responses and live leases', {
  skip: process.env.CATALOGUE_STORAGE_INTEGRATION !== '1',
}, async t => {
  require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });
  const schema = `moviehub_cache_test_${randomBytes(8).toString('hex')}`;
  assert.match(schema, /^moviehub_cache_test_[a-f0-9]{16}$/);
  await database.query(`CREATE SCHEMA ${schema}`);
  t.after(async () => { await database.query(`DROP SCHEMA ${schema} CASCADE`); });
  const setSchema = { text: `SET LOCAL search_path TO ${schema}` };
  const db = {
    query: async (text, parameters = []) =>
      (await database.transaction([setSchema, { text, parameters }]))[1],
    transaction: async statements =>
      (await database.transaction([setSchema, ...statements])).slice(1),
  };
  // Exercise migration from the currently deployed table layout.
  await db.query(`CREATE TABLE moviehub_catalogue_cache (
    cache_key text PRIMARY KEY, body jsonb, fresh_until bigint NOT NULL DEFAULT 0,
    stale_until bigint NOT NULL DEFAULT 0, lease_until bigint NOT NULL DEFAULT 0,
    lease_owner text, retry_at bigint NOT NULL DEFAULT 0)`);
  await db.query(`INSERT INTO moviehub_catalogue_cache (cache_key, body, fresh_until, stale_until)
    VALUES ('legacy', '{"results":[]}'::jsonb, 500, 10000)`);
  const maxBytes = 2000;
  const a = createCatalogueStore(db, { maxBytes }), b = createCatalogueStore(db, { maxBytes });
  await a.read('legacy');
  await b.read('legacy');
  const legacy = await db.query(`SELECT payload_bytes, octet_length(body::text) AS actual
    FROM moviehub_catalogue_cache WHERE cache_key = 'legacy'`);
  assert.equal(Number(legacy[0].payload_bytes), legacy[0].actual);
  async function usage() {
    const [row] = await db.query(`SELECT coalesce(sum(payload_bytes),0)::int AS bytes,
      coalesce(sum(octet_length(body::text)),0)::int AS actual FROM moviehub_catalogue_cache`);
    assert.equal(row.bytes, row.actual);
    assert.ok(row.bytes <= maxBytes, `Cache exceeded budget: ${row.bytes}`);
    return row.bytes;
  }
  async function publish(store, id, extra = 'data'.repeat(150), fresh = 10000) {
    assert.equal(await store.acquire(id, id, 1000, 60000), true);
    await store.publish(id, id, { results: [{ id, extra }] }, fresh, fresh + 1000);
    await usage();
  }
  await publish(a, 'oldest', undefined, 2000);
  await publish(a, 'middle', undefined, 3000);
  await publish(a, 'newest', undefined, 4000);
  await publish(a, 'last', undefined, 5000);
  assert.equal((await a.read('oldest')).body, null);
  assert.ok((await a.read('last')).body);

  // Distinct adapter instances must serialize budget checks under contention.
  await Promise.all(Array.from({ length: 8 }, (_, i) => publish(i % 2 ? a : b, `parallel-${i}`)));
  await usage();
  await publish(a, 'too-large', 'x'.repeat(maxBytes + 1));
  const oversized = await a.read('too-large');
  assert.equal(oversized.body, null);
  assert.equal(Number(oversized.lease_until), 0);

  // Eviction may clear old payloads but must retain an in-flight refresh lease.
  await publish(a, 'refreshing', undefined, 1001);
  assert.equal(await a.acquire('refreshing', 'active-owner', 1002, 60000), true);
  for (let i = 0; i < 4; i++) await publish(b, `evict-${i}`, undefined, 20000 + i);
  const [refreshing] = await db.query(`SELECT body, lease_owner, lease_until
    FROM moviehub_catalogue_cache WHERE cache_key = 'refreshing'`);
  assert.equal(refreshing.body, null);
  assert.equal(refreshing.lease_owner, 'active-owner');
  assert.equal(Number(refreshing.lease_until), 61002);
  await a.cleanup(1003);
  await usage();
  assert.equal((await a.read('refreshing')).body, null);
  // Shared Wambesha quotas reuse these atomic buckets across instances.
  const quota = await Promise.all(Array.from({ length: 20 }, (_, index) =>
    (index % 2 ? a : b).consume('wambesha:concurrent-test', 900001, 3)));
  assert.equal(quota.filter(retry => retry === 0).length, 3);
  assert.ok(quota.filter(retry => retry > 0).every(retry => retry === 60));
});
