const { setTimeout: delay } = require('node:timers/promises');

// A latency-controlled stand-in, explicitly not a PostgreSQL capacity model.
function memoryStore(latencyMs = 5) {
  const entries = new Map(), buckets = new Map();
  const calls = {};
  async function step(name) { calls[name] = (calls[name] || 0) + 1; if (latencyMs) await delay(latencyMs); }
  return {
    calls,
    async read(key) { await step('read'); return entries.get(key); },
    async acquire(key, owner, now, duration) {
      await step('acquire');
      const old = entries.get(key);
      if (old && (old.lease_until > now || old.fresh_until > now || old.retry_at > now)) return false;
      entries.set(key, { ...old, owner, lease_until: now + duration }); return true;
    },
    async publish(key, owner, body, fresh_until, stale_until) {
      await step('publish');
      if (entries.get(key)?.owner === owner) entries.set(key,
        { body, fresh_until, stale_until, lease_until: 0, retry_at: 0 });
    },
    async release(key, owner, retry_at) {
      await step('release');
      const old = entries.get(key);
      if (old?.owner === owner) entries.set(key, { ...old, owner: null, lease_until: 0, retry_at });
    },
    async consume(key, now, maximum, duration = 60000) {
      await step('consume');
      const start = Math.floor(now / duration) * duration;
      let bucket = buckets.get(key);
      if (!bucket || bucket.start !== start) { bucket = { start, hits: 0 }; buckets.set(key, bucket); }
      if (bucket.hits >= maximum) return Math.max(1, Math.ceil((start + duration - now) / 1000));
      bucket.hits++; return 0;
    },
    async cleanup(now) {
      await step('cleanup');
      for (const [key, bucket] of buckets) if (bucket.start < now - 120000) buckets.delete(key);
      for (const [key, entry] of entries) if (entry.stale_until < now && entry.lease_until <= now) entries.delete(key);
      while (entries.size > 2000) entries.delete(entries.keys().next().value);
    },
  };
}

async function neonStore() {
  const path = require('node:path');
  const { randomBytes } = require('node:crypto');
  require('dotenv').config({ path: path.join(__dirname, '../.env'), quiet: true });
  const { database } = require('../neon_database');
  const { createCatalogueStore } = require('../catalogue_store');
  const schema = `moviehub_load_${randomBytes(8).toString('hex')}`;
  if (!/^moviehub_load_[a-f0-9]{16}$/.test(schema)) throw new Error('Invalid isolated schema');
  await database.query(`CREATE SCHEMA ${schema}`);
  const lock = randomBytes(4).readUInt32BE() & 0x7fffffff;
  const calls = {};
  const qualify = text => text.replace(/\b(moviehub_catalogue_(?:cache|limits))\b/g, `${schema}.$1`);
  function statement(input) {
    // Do not contend on the production catalogue's advisory lock.
    return { text: qualify(input.text), parameters: input.text.includes('pg_advisory_xact_lock')
      ? [75482, lock] : input.parameters || [] };
  }
  const scoped = {
    query(text, parameters) { calls.query = (calls.query || 0) + 1; return database.query(qualify(text), parameters); },
    transaction(items) { calls.transaction = (calls.transaction || 0) + 1; return database.transaction(items.map(statement)); },
  };
  const cleanup = () => database.query(`DROP SCHEMA ${schema} CASCADE`);
  try {
    const store = createCatalogueStore(scoped, { maxBytes: 2 * 1024 * 1024 });
    await store.read('initialize-load-tables');
    return { store, calls, schema, cleanup };
  } catch (error) { await cleanup(); throw error; }
}

module.exports = { memoryStore, neonStore };
