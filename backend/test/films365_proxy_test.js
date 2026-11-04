const assert = require('node:assert/strict');
const test = require('node:test');
const app = require('../server');
const realFetch = global.fetch;

async function fixture(t) {
  const server = app.listen(0);
  t.after(() => new Promise(resolve => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

// FILMS365 was retired by the Wambesha/TMDB migration. These regressions
// protect that boundary instead of calling the removed proxy implementation.
test('retired FILMS365 routes stay unavailable and never contact an upstream', async t => {
  const origin = await fixture(t);
  let upstreamCalls = 0;
  t.mock.method(global, 'fetch', async () => { upstreamCalls++; throw new Error('Unexpected provider access'); });
  for (const [route, method] of [
    ['/api/mobile/trending', 'GET'], ['/api/mobile/popular', 'GET'],
    ['/api/mobile/latest', 'GET'], ['/api/mobile/explore', 'GET'],
    ['/api/mobile/details?type=movie&id=example', 'GET'],
    ['/api/mobile/person?type=movie&tmdbId=1', 'GET'],
    ['/api/mobile/search', 'POST'], ['/api/mobile/details/torrent-link', 'POST'],
    ['/api/mobile/unknown', 'GET'],
  ]) {
    const response = await realFetch(origin + route, { method });
    await response.arrayBuffer();
    assert.equal(response.status, 404, `${method} ${route}`);
  }
  assert.equal(app.locals.proxyFilms365Request, undefined);
  assert.equal(upstreamCalls, 0);
});

test('current private catalogue and download routes require Firebase ID tokens', async t => {
  const origin = await fixture(t);
  for (const [route, method] of [
    ['/api/database/health', 'GET'], ['/api/movies', 'GET'],
    ['/api/download/request', 'POST'], ['/api/wambesha/genres', 'GET'],
    ['/api/wambesha/search?q=Arrival', 'GET'], ['/api/wambesha/titles/mv_123/sources', 'GET'],
  ]) {
    const response = await realFetch(origin + route, { method });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: 'A Firebase ID token is required.' });
  }
});

test('request logs classify active and retired routes without recording queries or credentials', async t => {
  const origin = await fixture(t);
  const logs = [];
  t.mock.method(console, 'log', line => logs.push(line));
  t.mock.method(console, 'warn', () => {});
  for (const [route, method, endpoint, status] of [
    ['/api/mobile/details?token=private-query', 'GET', '/api/other', 404],
    ['/api/wambesha/genres', 'GET', '/api/wambesha/genres', 401],
    ['/api/wambesha/titles/mv_123/sources', 'GET', '/api/wambesha/titles/:id/sources', 401],
    ['/api/catalogue/3/account?token=private-query', 'GET', '/api/catalogue', 404],
    ['/api/movies', 'GET', '/api/movies', 401],
    ['/api/movies/example', 'GET', '/api/movies/:id', 401],
    ['/api/download/request', 'POST', '/api/download/request', 401],
    ['/api/download/stream', 'GET', '/api/download/stream', 400],
    ['/api/unknown', 'GET', '/api/other', 404],
  ]) {
    const response = await realFetch(origin + route, { method });
    await response.arrayBuffer();
    assert.equal(response.status, status);
    const trace = JSON.parse(logs.at(-1));
    assert.equal(trace.endpoint, endpoint);
    assert.equal(trace.status, status);
    assert.ok(trace.requestId);
    assert.equal(trace.requestId, response.headers.get('x-moviehub-request-id'));
    assert.ok(response.headers.get('x-moviehub-backend-instance'));
  }
  assert.doesNotMatch(logs.join(' '), /private-query|token=/);
});
