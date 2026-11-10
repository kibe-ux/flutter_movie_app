const assert = require('node:assert/strict');
const test = require('node:test');
const express = require('express');
const { registerWambeshaRoutes } = require('../wambesha');
const { createWambeshaLimits } = require('../wambesha_limits');
const { memoryRateStore } = require('../test_support/memory_rate_store');
const { MAX_RESPONSE_BYTES, MAX_PROVIDER_TASKS } = require('../wambesha_resources');

async function fixture(t, fetchImpl, fixedUid, limits = createWambeshaLimits({ store: memoryRateStore() }), options = {}) {
  const app = express();
  registerWambeshaRoutes(app, {
    authenticate: (req, res, next) => req.header('authorization') === 'Bearer firebase-token'
      ? (req.firebaseUser = { uid: fixedUid || req.header('x-test-user') || 'test-user' }, next()) : res.status(401).json({ error: 'Sign in required.' }),
    fetchImpl, limits, ...options,
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

test('current links envelope returns validated downloads for existing clients', async t => {
  const expires = new Date(Date.now() + 3600000).toISOString();
  const request = await fixture(t, async () => Response.json({
    id: 'mv_123', unverified: 0,
    links: [
      { kind: 'file_holding', url: 'https://files.example/movie.mp4', quality: '1080p', expires_at: expires },
      { kind: 'playback_holding', url: 'https://files.example/play.mp4', expires_at: expires },
      { kind: 'file_holding', url: 'http://files.example/insecure' },
      { kind: 'file_holding', url: 'https://files.example/expired', expires_at: '2000-01-01T00:00:00Z' },
      { kind: 'torrent_listing', url: 'magnet:private' },
    ],
    subtitles: [{ url: 'https://private.example/subtitle' }], magnets: ['private-evidence'],
  }));
  const response = await request('/titles/mv_123/sources');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body.sources.map(s => s.kind), ['file_holding', 'playback_holding']);
  assert.equal(body.sources[0].quality, '1080p');
  assert.doesNotMatch(JSON.stringify(body), /private|torrent|insecure|expired/);
});

test('empty current links are valid but malformed links are not cached', async t => {
  let calls = 0;
  const bodies = [{ links: 'invalid' }, { links: [] }];
  const request = await fixture(t, async () => Response.json(bodies[calls++]));
  assert.equal((await request('/titles/mv_123/sources')).status, 502);
  const response = await request('/titles/mv_123/sources');
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).sources, []);
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
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

test('lookup and episode resolution use the general budget and source failures are not retried or cached', async t => {
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


test('unknown provider exceptions are redacted for source requests and concurrent waiters', async t => {
  const request = await fixture(t, async () => {
    await new Promise(resolve => setTimeout(resolve, 25));
    throw new Error('private-url?api_key=secret-in-error');
  });
  const responses = await Promise.all(Array.from({ length: 4 }, () => request('/titles/mv_123/sources')));
  for (const response of responses) {
    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: 'Movie catalogue is unavailable.' });
  }
});

test('timeouts and malformed provider JSON return controlled messages', async t => {
  let timeout = true;
  const request = await fixture(t, async () => {
    if (timeout) throw Object.assign(new Error('private-provider-url'), { name: 'TimeoutError' });
    return new Response('private-malformed-json', { status: 200 });
  });
  const first = await request('/genres');
  assert.equal(first.status, 504);
  assert.deepEqual(await first.json(), { error: 'Movie catalogue request timed out.' });
  timeout = false;
  const second = await request('/genres');
  assert.equal(second.status, 502);
  assert.deepEqual(await second.json(), { error: 'Movie catalogue is unavailable.' });
});

test('simultaneous source requests stay isolated between verified users', async t => {
  let calls = 0;
  const request = await fixture(t, async () => {
    const call = ++calls;
    await new Promise(resolve => setTimeout(resolve, 25));
    return Response.json({ sources: [{ kind: 'file_holding', url: `https://delivery.example/${call}.mp4` }] });
  });
  const responses = await Promise.all([
    request('/titles/mv_123/sources', { headers: { 'x-test-user': 'first-user' } }),
    request('/titles/mv_123/sources', { headers: { 'x-test-user': 'second-user' } }),
  ]);
  const bodies = await Promise.all(responses.map(response => response.json()));
  assert.equal(calls, 2);
  assert.notEqual(bodies[0].sources[0].url, bodies[1].sources[0].url);
});

test('client-supplied test headers cannot override a verified UID', async t => {
  let calls = 0;
  const request = await fixture(t, async () => { calls++; return Response.json({ sources: [] }); }, 'verified-user');
  await request('/titles/mv_123/sources', { headers: { 'x-test-user': 'spoofed-user-one' } });
  await request('/titles/mv_123/sources', { headers: { 'x-test-user': 'spoofed-user-two' } });
  assert.equal(calls, 1);
});

test('duplicate source taps share one verification without consuming extra rate allowance', async t => {
  let calls = 0;
  const request = await fixture(t, async () => {
    calls++;
    await new Promise(resolve => setTimeout(resolve, 25));
    return Response.json({ sources: [] });
  });
  const responses = await Promise.all(Array.from({ length: 12 }, () => request('/titles/mv_123/sources')));
  assert.ok(responses.every(response => response.status === 200));
  assert.equal(calls, 1);
});

test('search and lookup share user and upstream quotas across server instances', async t => {
  const store = memoryRateStore();
  const options = { store, clientLimit: 2, upstreamLimit: 3 };
  let calls = 0;
  const provider = async () => { calls++; return Response.json({ items: [] }); };
  const a = await fixture(t, provider, undefined, createWambeshaLimits(options));
  const b = await fixture(t, provider, undefined, createWambeshaLimits(options));
  assert.equal((await a('/search?q=Arrival')).status, 200);
  assert.equal((await b('/lookup?tmdb_id=42')).status, 200);
  const clientLimited = await a('/genres');
  assert.equal(clientLimited.status, 429);
  assert.ok(Number(clientLimited.headers.get('retry-after')) > 0);
  assert.equal((await b('/genres', { headers: { 'x-test-user': 'other' } })).status, 200);
  const globalLimited = await a('/genres', { headers: { 'x-test-user': 'third' } });
  assert.equal(globalLimited.status, 503);
  assert.ok(Number(globalLimited.headers.get('retry-after')) > 0);
  assert.equal(calls, 3);
});

test('quota failures stop all upstream access and errors remain private', async t => {
  let calls = 0;
  const limits = createWambeshaLimits({ store: {
    consume: async () => { throw new Error('database-password'); },
  } });
  const request = await fixture(t, async () => { calls++; }, undefined, limits);
  const response = await request('/search?q=Arrival');
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('retry-after'), '15');
  assert.doesNotMatch(await response.text(), /database-password/);
  assert.equal(calls, 0);
});

test('oversized streamed sources are cancelled, redacted, coalesced and never cached', async t => {
  let calls = 0;
  let cancelled = false;
  const request = await fixture(t, async () => {
    calls++;
    if (calls > 1) return Response.json({ sources: [] });
    await new Promise(resolve => setTimeout(resolve, 25));
    return new Response(new ReadableStream({
      start(controller) { controller.enqueue(new Uint8Array(MAX_RESPONSE_BYTES + 1)); },
      cancel() { cancelled = true; },
    }), { headers: { 'content-length': '1' } });
  });
  const responses = await Promise.all(Array.from({ length: 4 }, () => request('/titles/mv_123/sources')));
  for (const response of responses) {
    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: 'Movie catalogue is unavailable.' });
  }
  assert.equal(cancelled, true);
  assert.equal(calls, 1);
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
  assert.equal(calls, 2);
});

test('response size limits cover search as well as source discovery', async t => {
  let cancelled = false;
  const request = await fixture(t, async () => new Response(new ReadableStream({
    cancel() { cancelled = true; },
  }), { headers: { 'content-length': String(MAX_RESPONSE_BYTES + 1) } }));
  const response = await request('/search?q=Arrival');
  assert.equal(response.status, 502);
  assert.equal(cancelled, true);
  assert.deepEqual(await response.json(), { error: 'Movie catalogue is unavailable.' });
});

test('provider errors discard unconsumed response bodies', async t => {
  let cancelled = false;
  const request = await fixture(t, async () => new Response(new ReadableStream({
    cancel() { cancelled = true; },
  }), { status: 503 }));
  assert.equal((await request('/genres')).status, 503);
  assert.equal(cancelled, true);
});

test('malformed source envelopes cannot enter the successful cache', async t => {
  const bodies = [null, [], {}, { sources: 'private-bad-sources' }, { sources: [] }];
  let calls = 0;
  const request = await fixture(t, async () => Response.json(bodies[calls++]));
  for (let i = 0; i < 4; i++) {
    const response = await request('/titles/mv_123/sources');
    assert.equal(response.status, 502);
    assert.doesNotMatch(await response.text(), /private/);
  }
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
  assert.equal(calls, 5);
});

test('cache refreshes before the earliest signed-link safety margin and rejects invalid expiry', async t => {
  let time = Date.parse('2026-11-05T00:00:00Z');
  const expiresAt = new Date(time + 45000).toISOString();
  let calls = 0;
  const request = await fixture(t, async () => {
    calls++;
    return Response.json({ sources: [
      { kind: 'file_holding', url: 'https://files.example/signed', expires_at: expiresAt },
      { kind: 'file_holding', url: 'https://files.example/no-expiry' },
      { kind: 'file_holding', url: 'https://files.example/bad', expires_at: 'private-invalid-date' },
      { kind: 'file_holding', url: 'https://files.example/number', expires_at: 123 },
      { kind: 'file_holding', url: 'https://files.example/soon', expires_at: new Date(time + 29000).toISOString() },
      { kind: 'file_holding', url: 'https://private:password@files.example/' },
    ] });
  }, undefined, undefined, { now: () => time });
  assert.equal((await (await request('/titles/mv_123/sources')).json()).sources.length, 2);
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
  assert.equal(calls, 1);
  time += 15000;
  const refreshed = await (await request('/titles/mv_123/sources')).json();
  assert.deepEqual(refreshed.sources.map(source => source.url), ['https://files.example/no-expiry']);
  assert.equal(calls, 2);
});

test('provider capacity bounds new work while followers share a slot and failures release capacity', async t => {
  const started = Promise.withResolvers();
  const gate = Promise.withResolvers();
  let calls = 0;
  const request = await fixture(t, async url => {
    calls++;
    if (calls === MAX_PROVIDER_TASKS) started.resolve();
    if (calls <= MAX_PROVIDER_TASKS) await gate.promise;
    if (url.pathname.includes('/mv_0/')) throw new Error('private-provider-detail');
    return Response.json({ sources: [] });
  });
  t.after(() => gate.resolve());
  const pending = Array.from({ length: MAX_PROVIDER_TASKS }, (_, i) => request(`/titles/mv_${i}/sources`));
  await started.promise;
  const follower = request('/titles/mv_0/sources');
  const refused = await request('/genres');
  assert.equal(refused.status, 503);
  assert.equal(refused.headers.get('retry-after'), '1');
  assert.equal(calls, MAX_PROVIDER_TASKS);
  gate.resolve();
  const responses = await Promise.all(pending);
  assert.equal(responses[0].status, 502);
  assert.ok(responses.slice(1).every(response => response.status === 200));
  assert.equal((await follower).status, 502);
  assert.equal((await request('/genres')).status, 200);
  assert.equal(calls, MAX_PROVIDER_TASKS + 1);
});

test('deadlines cover stalled headers and bodies, clear pending work, and do not cache failures', {
  timeout: 10000,
}, async t => {
  for (const stall of ['headers', 'body']) {
    let calls = 0;
    let cancelled = false;
    const request = await fixture(t, async () => {
      calls++;
      if (calls > 1) return Response.json({ sources: [] });
      if (stall === 'headers') return new Promise(() => {});
      return new Response(new ReadableStream({ cancel() { cancelled = true; } }));
    }, undefined, undefined, { providerTimeoutMs: 50 });
    const response = await request('/titles/mv_123/sources');
    assert.equal(response.status, 504);
    assert.deepEqual(await response.json(), { error: 'Movie catalogue request timed out.' });
    if (stall === 'body') assert.equal(cancelled, true);
    assert.equal((await request('/titles/mv_123/sources')).status, 200);
    assert.equal(calls, 2);
  }
});


test('source usage distinguishes cached responses and verification metadata without secrets', async t => {
  const events = [];
  let calls = 0;
  const request = await fixture(t, async () => {
    calls++;
    return Response.json({ verification_spent: true, links: [{ kind: 'file_holding',
      url: 'https://files.example/private?sig=secret', expires_at: new Date(Date.now() + 120000).toISOString() }] });
  }, undefined, undefined, { onUsage: event => events.push(event) });
  assert.equal((await request('/titles/mv_123/sources')).status, 200);
  const cached = await request('/titles/mv_123/sources');
  assert.equal(cached.headers.get('x-moviehub-source-cache'), 'HIT');
  assert.equal(calls, 1);
  assert.equal(events.filter(row => row.event === 'upstream-request').length, 1);
  assert.equal(events.find(row => row.event === 'verification').spent, 1);
  assert.equal(events.filter(row => row.event === 'cache-hit').length, 1);
  assert.doesNotMatch(JSON.stringify(events), /sig=|secret|firebase-token|test-user|private-provider-key/);
});

test('source cache identities separate language variants', async t => {
  let calls = 0;
  const request = await fixture(t, async () => {
    calls++;
    return Response.json({ verification_spent: false, links: [] });
  }, undefined, undefined, { onUsage: () => {} });
  await request('/titles/mv_123/sources?language=en');
  await request('/titles/mv_123/sources?language=fr');
  await request('/titles/mv_123/sources?language=en');
  assert.equal(calls, 2);
});


test('opt-in route cache reuses explicit-expiry sources across users and instances', async t => {
  const rows = new Map();
  const store = {
    async read(key) { return rows.get(key); },
    async acquire(key, owner, now, lease) {
      const row = rows.get(key);
      if (row && (row.lease_until > now || row.fresh_until > now)) return false;
      rows.set(key, { ...row, owner, lease_until: now + lease });
      return true;
    },
    async publish(key, owner, body, fresh_until) {
      assert.equal(rows.get(key).owner, owner);
      rows.set(key, { body, fresh_until, lease_until: 0 });
    },
    async release(key, owner, retry_at) {
      rows.set(key, { ...rows.get(key), lease_until: 0, retry_at });
    },
  };
  let calls = 0;
  const provider = async () => {
    calls++;
    await new Promise(resolve => setTimeout(resolve, 20));
    return Response.json({ verification_spent: true, links: [{ kind: 'file_holding',
      url: 'https://files.example/signed', expires_at: new Date(Date.now() + 120000).toISOString() }] });
  };
  const config = { sharedSources: true, sourceStore: store, onUsage: () => {} };
  const a = await fixture(t, provider, 'user-a', undefined, config);
  const b = await fixture(t, provider, 'user-b', undefined, config);
  const responses = await Promise.all([a('/titles/mv_123/sources'), b('/titles/mv_123/sources')]);
  assert.deepEqual(responses.map(response => response.status), [200, 200]);
  assert.equal(calls, 1);
  assert.deepEqual(await responses[0].json(), await responses[1].json());
  assert.equal(rows.size, 1);
  assert.ok([...rows.keys()][0].startsWith('wambesha-source:v1:'));
});
