const assert = require('node:assert/strict');
const test = require('node:test');
const express = require('express');
const { setTimeout: delay } = require('node:timers/promises');
const { catalogueRequest, createCatalogue, registerCatalogueRoutes } = require('../catalogue');
const { createCatalogueStore } = require('../catalogue_store');

function memoryStore() {
  const entries = new Map(), limits = new Map();
  return {
    entries,
    async read(key) { return entries.get(key); },
    async acquire(key, owner, now, duration) {
      const old = entries.get(key);
      if (old && (old.lease_until > now || old.fresh_until > now || old.retry_at > now)) return false;
      entries.set(key, { ...old, owner, lease_until: now + duration }); return true;
    },
    async publish(key, owner, body, fresh_until, stale_until) {
      if (entries.get(key)?.owner === owner) entries.set(key, { body, fresh_until, stale_until, lease_until: 0, retry_at: 0 });
    },
    async release(key, owner, retry_at) {
      const old = entries.get(key);
      if (old?.owner === owner) entries.set(key, { ...old, lease_until: 0, owner: null, retry_at });
    },
    async consume(key, now, limit, duration = 60000) {
      const start = Math.floor(now / duration) * duration;
      let old = limits.get(key);
      if (!old || old.start !== start) { old = { start, hits: 0 }; limits.set(key, old); }
      if (old.hits >= limit) return Math.max(1, Math.ceil((start + duration - now) / 1000));
      old.hits++; return 0;
    },
    async cleanup() {},
  };
}
const page = id => Response.json({ results: [{ id }], total_pages: 3 });
const request = (path = '/movie/popular', query = {}) => catalogueRequest(path, query);
function service(store, options = {}) {
  return createCatalogue({ store, keyProvider: () => 'server-private-key', ...options });
}

test('canonical keys share parameter ordering and defaults, but separate pages and filters', () => {
  assert.equal(request().key, request('/movie/popular', { page: '1', language: 'en-US' }).key);
  assert.notEqual(request().key, request('/movie/popular', { page: '2' }).key);
  assert.notEqual(request('/discover/movie', { with_genres: '35' }).key,
    request('/discover/movie', { with_genres: '18' }).key);
  assert.equal(request('/movie/1', { append_to_response: 'videos,credits' }).key,
    request('/movie/1', { append_to_response: 'credits,videos' }).key);
});

test('the proxy rejects unknown routes, secrets, repeated parameters and cache-busting options', () => {
  for (const [path, query] of [
    ['/account', {}], ['/movie/1/account_states', {}], ['/https://evil.test', {}],
    ['/movie/popular', { api_key: 'client-secret' }],
    ['/movie/popular', { page: ['1', '2'] }], ['/movie/popular', { page: '501' }],
    ['/movie/popular', { refresh: 'true' }], ['/movie/popular', { callback: 'evil' }],
    ['/movie/popular', { constructor: 'value' }],
    ['/movie/popular', { with_genres: '35' }], ['/search/movie', { query: 'x' }],
    ['/movie/1', { append_to_response: 'account_states' }],
  ]) assert.throws(() => request(path, query), error => [400, 404].includes(error.status));
});

test('different users and different API instances share one persistent provider response', async () => {
  let calls = 0;
  const store = memoryStore();
  const fetchImpl = async (url, options) => {
    calls++;
    assert.equal(url.origin, 'https://api.themoviedb.org');
    assert.equal(url.searchParams.get('api_key'), 'server-private-key');
    assert.equal(options.redirect, 'error');
    return page(1);
  };
  assert.equal((await service(store, { fetchImpl }).get(request(), 'user:a')).cache, 'MISS');
  assert.equal((await service(store, { fetchImpl }).get(request(), 'user:b')).cache, 'HIT');
  assert.equal(calls, 1);
});

test('simultaneous misses across two API instances make only one provider request', async () => {
  let calls = 0, complete;
  const upstream = new Promise(resolve => { complete = resolve; });
  const store = memoryStore();
  const options = { fetchImpl: async () => { calls++; return upstream; }, sleep: () => delay(5) };
  const a = service(store, options), b = service(store, options);
  const replies = Array.from({ length: 20 }, (_, i) => (i % 2 ? a : b).get(request(), `user:${i}`));
  await delay(20);
  assert.equal(calls, 1);
  complete(page(1));
  const results = await Promise.all(replies);
  assert.ok(results.every(value => value.body.results[0].id === 1));
  assert.equal(results.filter(value => value.cache === 'MISS').length, 1);
});

test('shared per-client limits apply to cache hits and reset at the next window', async () => {
  let now = 1000, calls = 0;
  const store = memoryStore();
  const a = service(store, { now: () => now, userLimit: 2, fetchImpl: async () => { calls++; return page(1); } });
  const b = service(store, { now: () => now, userLimit: 2, fetchImpl: () => assert.fail('Cached') });
  await a.get(request(), 'user:one');
  await b.get(request(), 'user:one');
  await assert.rejects(a.get(request(), 'user:one'), { status: 429, retryAfter: 59 });
  await b.get(request(), 'user:two');
  now += 60000;
  await b.get(request(), 'user:one');
  assert.equal(calls, 1);
});

test('changing guest identities cannot bypass the global upstream budget', async () => {
  let calls = 0;
  const store = memoryStore();
  const options = { upstreamLimit: 1, now: () => 1000, fetchImpl: async () => { calls++; return page(1); } };
  await service(store, options).get(request(), 'guest:a');
  await assert.rejects(service(store, options).get(request('/tv/popular'), 'guest:b'), { status: 503 });
  assert.equal(calls, 1);
});

test('refresh after expiry replaces data; provider failures serve a still-valid stale copy', async () => {
  let now = 1000, calls = 0;
  const store = memoryStore();
  const options = { now: () => now, ttlMs: 100, staleMs: 1000,
    fetchImpl: async () => { calls++; return calls === 2 ? new Response('sensitive failure', { status: 500 }) : page(calls); } };
  const api = service(store, options);
  await api.get(request(), 'user:a');
  now += 101;
  assert.equal((await api.get(request(), 'user:a')).cache, 'STALE');
  assert.equal((await service(store, options).get(request(), 'user:b')).cache, 'STALE');
  assert.equal(calls, 2);
  now += 15001;
  assert.equal((await api.get(request(), 'user:a')).body.results[0].id, 3);
});

test('cold failures have a shared cooldown and errors never expose provider details', async () => {
  let calls = 0, now = 1000;
  const store = memoryStore();
  const options = { now: () => now, fetchImpl: async () => {
    calls++; throw new Error('https://provider/?api_key=secret-password');
  } };
  for (let i = 0; i < 2; i++) await assert.rejects(service(store, options).get(request(), `user:${i}`), error =>
    error.status === 503 && !error.message.includes('secret-password'));
  assert.equal(calls, 1);
  now += 15001;
  await assert.rejects(service(store, options).get(request(), 'user:three'), { status: 503 });
  assert.equal(calls, 2);
});

test('invalid and oversized provider responses are never cached', async () => {
  for (const response of [Response.json({ error: 'bad' }), Response.json({ results: 'bad' }),
    new Response('x'.repeat(1024 * 1024 + 1)), Response.json({ success: false, results: [] })]) {
    const store = memoryStore();
    await assert.rejects(service(store, { fetchImpl: async () => response }).get(request(), 'user:a'), { status: 503 });
    assert.ok([...store.entries.values()].every(entry => !entry.body));
  }
});

test('a database outage fails closed without calling the provider', async () => {
  const store = memoryStore();
  store.consume = async () => { throw new Error('database-private-connection'); };
  await assert.rejects(service(store, { fetchImpl: () => assert.fail('No upstream fallback') }).get(request(), 'guest:a'), error =>
    error.status === 503 && !error.message.includes('database-private'));
});

test('the bounded local cache evicts old pages while the persistent cache avoids refetching them', async () => {
  let reads = 0, calls = 0;
  const store = memoryStore(), originalRead = store.read;
  store.read = async key => { reads++; return originalRead(key); };
  const api = service(store, { fetchImpl: async () => { calls++; return page(1); } });
  for (let i = 1; i <= 129; i++) {
    await api.get(request('/movie/popular', { page: String(i) }), `user:${i}`);
  }
  assert.equal(reads, 129);
  await api.get(request('/movie/popular', { page: '129' }), 'user:again');
  assert.equal(reads, 129);
  await api.get(request(), 'user:again');
  assert.equal(reads, 130);
  assert.equal(calls, 129);
});

test('an abandoned lease times out without duplicate provider work', async () => {
  let now = 1000;
  const store = memoryStore(), req = request();
  await store.acquire(req.key, 'old-instance', now, 60000);
  await assert.rejects(service(store, { now: () => now, waitMs: 1000,
    sleep: async () => { now += 250; }, fetchImpl: () => assert.fail('Lease is active') }).get(req, 'user:a'), { status: 503 });
  now += 60000;
  assert.equal((await service(store, { now: () => now, fetchImpl: async () => page(1) }).get(req, 'user:b')).cache, 'MISS');
});

test('PostgreSQL store uses parameterized atomic leases and limits, and schema setup can retry', async () => {
  const calls = []; let fail = true;
  const query = async (sql, parameters = []) => {
    calls.push({ sql, parameters });
    if (fail) { fail = false; throw new Error('temporary'); }
    return sql.includes('RETURNING') ? [{ cache_key: 'key', hits: 1 }] : [];
  };
  const store = createCatalogueStore({ query,
    transaction: statements => Promise.all(statements.map(s => query(s.text, s.parameters))),
  });
  await assert.rejects(store.read('key'));
  await store.read('key');
  assert.equal(await store.acquire('key', 'owner', 1000, 60000), true);
  assert.equal(await store.consume('client:hash', 1000, 120), 0);
  await store.publish('key', 'owner', { results: [] }, 2000, 3000);
  await store.release('key', 'owner', 4000);
  await store.cleanup(5000);
  assert.ok(calls.some(call => call.sql.includes('lease_owner = $2') && call.sql.includes('ON CONFLICT')));
  assert.ok(calls.some(call => call.sql.includes('hits < $3')));
  assert.ok(calls.some(call => call.sql.includes('pg_advisory_xact_lock')));
  assert.ok(calls.some(call => call.sql.includes('retained_bytes > $2') && call.parameters[1] === 100_000_000));
  assert.ok(calls.filter(call => !/^(CREATE|ALTER|UPDATE moviehub_catalogue_cache\n\s+SET payload_bytes)/.test(call.sql))
    .every(call => call.parameters.length > 0));
});

test('storage budgets cannot exceed the 100 MB ceiling', () => {
  for (const maxBytes of [0, -1, 100_000_001, NaN]) {
    assert.throws(() => createCatalogueStore({}, { maxBytes }), RangeError);
  }
});

async function fixture(t, options = {}) {
  const app = express(), identities = [];
  registerCatalogueRoutes(app, {
    authenticate: (req, res, next) => req.header('authorization') === 'Bearer verified-token'
      ? (req.firebaseUser = { uid: 'verified-uid' }, next())
      : res.set('X-MovieHub-Response-Source', 'firebase-auth').status(401).json({ error: 'Invalid token' }),
    service: { get: async (req, identity) => { identities.push(identity); return { cache: 'HIT', body: { results: [] } }; }, ...options },
  });
  const server = app.listen(0);
  t.after(() => new Promise(resolve => server.close(resolve)));
  return { identities, get: (path = '/movie/popular', headers = {}, method = 'GET') =>
    fetch(`http://127.0.0.1:${server.address().port}/api/catalogue/3${path}`, {
      method, headers: { 'X-MovieHub-Installation': 'a'.repeat(32), ...headers },
    }) };
}

test('guest browsing works; signed-in users use verified UIDs, never a spoofed header', async t => {
  const f = await fixture(t);
  const guest = await f.get();
  assert.equal(guest.status, 200);
  assert.equal(guest.headers.get('cache-control'), 'no-store');
  assert.equal(guest.headers.get('x-moviehub-cache'), 'HIT');
  await f.get('/movie/popular', { Authorization: 'Bearer verified-token', 'x-test-user': 'spoof' });
  assert.deepEqual(f.identities, [`guest:${'a'.repeat(32)}`, 'user:verified-uid']);
  assert.equal((await f.get('/movie/popular', { Authorization: 'Bearer bad' })).status, 401);
  assert.equal((await f.get('/movie/popular', { 'X-MovieHub-Installation': '' })).status, 400);
  assert.equal((await f.get('/movie/popular', {}, 'POST')).status, 405);
  assert.equal((await f.get('/movie/popular?api_key=private')).status, 400);
});

test('rate-limit responses include Retry-After without exposing exceptions', async t => {
  const { CatalogueError } = require('../catalogue');
  const f = await fixture(t, { get: async () => { throw new CatalogueError(429, 'Too many requests.', 20); } });
  const response = await f.get();
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('retry-after'), '20');
});
