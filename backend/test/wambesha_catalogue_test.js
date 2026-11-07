const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { catalogueRequest, createCatalogue, registerCatalogueRoutes } = require('../catalogue');
const { fetchWambeshaCatalogue } = require('../wambesha_catalogue');

const record = (id = 'mv_ONE', tmdb = '278', extras = {}) => ({
  id, type: 'movie', title: 'Catalogue movie', year: 1994, release_date: '1994-09-23',
  external_ids: { tmdb_id: tmdb }, status: 'released',
  poster: { url: 'https://images.example/poster.webp' },
  ratings: [{ source: 'TMDB', score: 8.7, max_score: 10 }], ...extras,
});
function provider(records, calls, next = 'opaque_next') {
  return async (url, options) => {
    calls.push(url);
    assert.equal(url.origin, 'https://api.wambesha.com');
    assert.equal(options.headers.Authorization, 'Bearer server-only-key');
    assert.equal(options.redirect, 'error');
    assert.equal(url.searchParams.has('api_key'), false);
    if (url.pathname === '/v1/discover') return Response.json({ items: records, next_cursor: next });
    assert.equal(url.pathname, '/v1/titles');
    return Response.json({ items: records, sources: ['must-not-be-public'], private_setting: 'must-not-be-public' });
  };
}
const request = (query = {}) => catalogueRequest('/wambesha/discover', query);

test('discovery route validates finite filters, opaque pagination and canonical cache identity', () => {
  assert.equal(request({ genre: 'thriller,action' }).key, request({ genre: 'action,thriller', page: '1', type: 'movie', sort: 'popularity' }).key);
  for (const query of [{ url: 'https://private' }, { type: 'person' }, { genre: '1' },
    { sort: 'arbitrary' }, { cursor: 'https://private' }, { page: '2' }, { page: ['1'] }]) {
    assert.throws(() => request(query));
  }
  assert.throws(() => catalogueRequest('/wambesha/titles/mv_ONE/sources', {}));
  assert.notEqual(request().key, catalogueRequest('/movie/popular', {}).key);
});

test('public catalogue returns genuine IDs and safe artwork but never sources or credentials', async () => {
  const calls = [];
  const records = [record(), record('mv_MISSING', null), record('mv_FUTURE', '3', { release_date: '2999-01-01' }),
    record('mv_WITHDRAWN', '4', { status: 'upcoming' }), record('sr_WRONG', '5', { type: 'series' })];
  const body = await fetchWambeshaCatalogue(request(), {
    fetchImpl: provider(records, calls), key: 'server-only-key', beforeFetch: async () => {},
  });
  assert.equal(calls.length, 2);
  assert.equal(body.results.length, 1);
  assert.equal(body.results[0].id, 278);
  assert.equal(body.results[0].wambesha_id, 'mv_ONE');
  assert.equal(body.results[0].poster_url, 'https://images.example/poster.webp');
  assert.equal(body.results[0].vote_average, 8.7);
  assert.equal(body.next_cursor, 'opaque_next');
  assert.doesNotMatch(JSON.stringify(body), /must-not-be-public|server-only-key|sources|private_setting/);
});

test('opaque cursor is forwarded without fabrication; empty normalized pages can still continue', async () => {
  const calls = [];
  const body = await fetchWambeshaCatalogue(request({ page: '2', cursor: 'opaque_first', genre: 'action', sort: 'rating' }), {
    fetchImpl: provider([record('mv_UNLINKED', null)], calls, 'opaque_last'),
    key: 'server-only-key', beforeFetch: async () => {},
  });
  assert.equal(calls[0].searchParams.get('cursor'), 'opaque_first');
  assert.equal(calls[0].searchParams.get('genre'), 'action');
  assert.equal(calls[0].searchParams.get('sort'), 'rating');
  assert.equal(calls[0].searchParams.has('page'), false);
  assert.deepEqual(body.results, []);
  assert.equal(body.has_more, true);
});

test('repeated cursors stop pagination', async () => {
  const body = await fetchWambeshaCatalogue(request({ page: '2', cursor: 'same' }), {
    fetchImpl: provider([], [], 'same'), key: 'server-only-key', beforeFetch: async () => {},
  });
  assert.equal(body.has_more, false);
});

test('public catalogue coalesces and caches across guests without metered source verification', async t => {
  const entries = new Map();
  const store = {
    async read(key) { return entries.get(key); }, async consume() { return 0; }, async cleanup() {},
    async acquire() { return true; }, async release() {},
    async publish(key, owner, body, fresh_until, stale_until) { entries.set(key, { body, fresh_until, stale_until }); },
  };
  const calls = [];
  const service = createCatalogue({ store, keyProvider: () => '', wambeshaKeyProvider: () => 'server-only-key',
    fetchImpl: provider([record()], calls) });
  const app = express();
  registerCatalogueRoutes(app, { service, authenticate: (req, res) => res.sendStatus(401) });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  const url = `http://127.0.0.1:${server.address().port}/api/catalogue/3/wambesha/discover`;
  const responses = await Promise.all(['a', 'b'].map(id => fetch(url, { headers: { 'X-MovieHub-Installation': id.repeat(32) } })));
  for (const response of responses) {
    assert.equal(response.status, 200);
    assert.equal((await response.json()).results[0].wambesha_id, 'mv_ONE');
  }
  assert.equal(calls.length, 2);
  assert.equal((await fetch(url, { headers: { 'X-MovieHub-Installation': 'c'.repeat(32) } })).headers.get('x-moviehub-cache'), 'HIT');
  assert.equal(calls.length, 2);
  assert.equal((await fetch(url)).status, 400);
});

test('provider failures and malformed envelopes are never accepted as an empty catalogue', async () => {
  for (const response of [new Response('private', { status: 403 }), Response.json({ error: 'private' })]) {
    await assert.rejects(fetchWambeshaCatalogue(request(), { fetchImpl: async () => response,
      key: 'server-only-key', beforeFetch: async () => {} }));
  }
});
