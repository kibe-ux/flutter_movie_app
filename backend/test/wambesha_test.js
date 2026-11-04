const assert = require('node:assert/strict');
const test = require('node:test');
const express = require('express');
const { registerWambeshaRoutes } = require('../wambesha');

async function fixture(t, fetchImpl) {
  const app = express();
  registerWambeshaRoutes(app, {
    authenticate: (req, res, next) => req.header('authorization') === 'Bearer firebase-token'
      ? (req.firebaseUser = { uid: req.header('x-test-user') || 'test-user' }, next()) : res.status(401).json({ error: 'Sign in required.' }),
    fetchImpl,
  });
  const server = app.listen(0);
  t.after(() => new Promise(resolve => server.close(resolve)));
  const previous = process.env.WAMBESHA_API_KEY;
  process.env.WAMBESHA_API_KEY = 'private-provider-key';
  t.after(() => {
    if (previous === undefined) delete process.env.WAMBESHA_API_KEY;
    else process.env.WAMBESHA_API_KEY = previous;
  });
  return (path, options = {}) => fetch(`http://127.0.0.1:${server.address().port}/api/wambesha${path}`, {
    ...options, headers: { Authorization: 'Bearer firebase-token', ...options.headers },
  });
}

test('Wambesha routes authenticate before making provider requests', async t => {
  const request = await fixture(t, () => { throw new Error('Must not call upstream'); });
  assert.equal((await request('/search?q=Arrival', { headers: { Authorization: '' } })).status, 401);
  // Verify the actual application registration also uses Firebase authentication.
  const app = require('../server');
  const server = app.listen(0);
  t.after(() => new Promise(resolve => server.close(resolve)));
  assert.equal((await fetch(`http://127.0.0.1:${server.address().port}/api/wambesha/search?q=Arrival`)).status, 401);
});

test('only the server credential is sent to the fixed provider origin', async t => {
  let calls = 0;
  const request = await fixture(t, async (url, options) => {
    calls++;
    assert.equal(url.origin, 'https://api.wambesha.com');
    assert.equal(url.pathname, '/v1/search');
    assert.equal(url.searchParams.get('q'), 'Arrival & more');
    assert.equal(options.headers.Authorization, 'Bearer private-provider-key');
    assert.equal(options.redirect, 'error');
    return Response.json({ titles: { items: [] } });
  });
  const response = await request('/search?q=Arrival%20%26%20more');
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('x-moviehub-response-source'), 'wambesha');
  assert.deepEqual(await response.json(), { titles: { items: [] } });
  for (const path of ['/account/keys', '/titles/mv_123/sources?form=uri', '/search?q=a',
    '/search?q=Arrival&api_key=client-key', '/titles?ids=https://other.example', '/genres?url=https://other.example']) {
    assert.ok([400, 404].includes((await request(path)).status));
  }
  assert.equal((await request('/search?q=Arrival', { method: 'POST' })).status, 405);
  assert.equal(calls, 1);
});

test('batch titles and genres route correctly; missing configuration fails closed', async t => {
  const paths = [];
  const request = await fixture(t, async url => {
    paths.push(url.pathname);
    return Response.json({ items: [] });
  });
  assert.equal((await request('/titles?ids=mv_123,sr_456')).status, 200);
  assert.equal((await request('/titles/mv_123')).status, 200);
  assert.equal((await request('/genres')).status, 200);
  delete process.env.WAMBESHA_API_KEY;
  assert.equal((await request('/genres')).status, 503);
  assert.deepEqual(paths, ['/v1/titles', '/v1/titles/mv_123', '/v1/genres']);
});

test('provider auth failures are not Firebase failures and provider bodies are withheld', async t => {
  let status = 401;
  const request = await fixture(t, async () => new Response('sensitive-provider-diagnostic', {
    status, headers: { 'retry-after': '60' },
  }));
  const denied = await request('/genres');
  assert.equal(denied.status, 502);
  assert.doesNotMatch(await denied.text(), /sensitive|private-provider-key/);
  status = 429;
  const limited = await request('/genres');
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get('retry-after'), '60');
});

test('transport and malformed JSON errors return a controlled response', async t => {
  const request = await fixture(t, async () => { throw new Error('secret-in-error'); });
  const response = await request('/genres');
  assert.equal(response.status, 502);
  assert.doesNotMatch(await response.text(), /secret-in-error/);
});


test('sources coalesce duplicate taps, filter kinds and reuse per user without exposing torrent evidence', async t => {
  let calls = 0;
  const expires = new Date(Date.now() + 3600000).toISOString();
  const request = await fixture(t, async (url, options) => {
    calls++;
    assert.equal(url.pathname, '/v1/titles/mv_123/sources');
    assert.equal(url.search, '');
    assert.equal(options.headers.Authorization, 'Bearer private-provider-key');
    await new Promise(resolve => setTimeout(resolve, 25));
    return Response.json({ id: 'mv_123', unverified: 1, sources: [
      { kind: 'file_holding', url: 'https://delivery.example/file.mp4?sig=private', expires_at: expires },
      { kind: 'playback_holding', url: 'https://delivery.example/play.mp4', expires_at: expires },
      { kind: 'torrent_listing', url: 'magnet:private', evidence: { info_hash: 'private' } },
      { kind: 'file_holding', url: 'http://delivery.example/insecure.mp4', expires_at: expires },
      { kind: 'file_holding', url: 'https://delivery.example/expired.mp4', expires_at: '2000-01-01T00:00:00Z' },
    ] });
  });
  const responses = await Promise.all([request('/titles/mv_123/sources'), request('/titles/mv_123/sources')]);
  const body = await responses[0].json();
  assert.deepEqual(body.sources.map(s => s.kind), ['file_holding', 'playback_holding']);
  assert.doesNotMatch(JSON.stringify(body), /torrent|info_hash/);
  assert.equal(body.unverified, 1);
  await request('/titles/mv_123/sources');
  assert.equal(calls, 1);
  await request('/titles/mv_123/sources', { headers: { 'x-test-user': 'another-user' } });
  assert.equal(calls, 2);
});

test('empty sources are briefly reused and per-user metering is limited', async t => {
  let calls = 0;
  const request = await fixture(t, async () => { calls++; return Response.json({ sources: [], unverified: 1 }); });
  for (let i = 0; i < 8; i++) assert.equal((await request(`/titles/ep_${i}/sources`)).status, 200);
  assert.equal((await request('/titles/ep_0/sources')).status, 200);
  const limited = await request('/titles/ep_9/sources');
  assert.equal(limited.status, 429);
  assert.ok(Number(limited.headers.get('retry-after')) > 0);
  assert.equal(calls, 8);
  const denied = await request('/titles/mv_123/sources', { headers: { Authorization: '' } });
  assert.equal(denied.status, 401);
  assert.equal(calls, 8);
});

test('lookup and episode resolution are unmetered and source failures are not retried or cached', async t => {
  let calls = 0;
  const request = await fixture(t, async () => {
    calls++;
    return calls <= 2 ? Response.json({ items: [] }) : new Response('{}', { status: 503 });
  });
  assert.equal((await request('/lookup?tmdb_id=329865')).status, 200);
  assert.equal((await request('/titles/sr_123/episodes?season=1&limit=50&cursor=next')).status, 200);
  assert.equal((await request('/titles/sr_123/episodes?limit=100')).status, 400);
  assert.equal((await request('/lookup?tmdb_id=1&imdb_id=tt123')).status, 400);
  assert.equal((await request('/titles/mv_123/sources')).status, 503);
  assert.equal(calls, 3);
  assert.equal((await request('/titles/mv_123/sources')).status, 503);
  assert.equal(calls, 4);
});
