const test = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('node:http');
const { gzipSync } = require('node:zlib');
const { readProviderJson, withAbort, createSourceCache,
  MAX_RESPONSE_BYTES, MAX_CACHE_BYTES, MAX_CACHE_ENTRIES } = require('../wambesha_resources');

const signal = () => new AbortController().signal;
const sources = (value = 'a') => ({ sources: [{ kind: 'file_holding', url: `https://files.example/${value}` }] });
const decode = buffer => buffer ? JSON.parse(buffer.toString('utf8')) : undefined;

test('the response byte limit accepts its exact boundary and measures multibyte JSON', async () => {
  const overhead = Buffer.byteLength(JSON.stringify({ value: '' }));
  const text = JSON.stringify({ value: 'x'.repeat(MAX_RESPONSE_BYTES - overhead) });
  assert.equal(Buffer.byteLength(text), MAX_RESPONSE_BYTES);
  assert.equal((await readProviderJson(new Response(text), signal())).value.length,
    MAX_RESPONSE_BYTES - overhead);
  await assert.rejects(readProviderJson(Response.json({ value: '😀'.repeat(300000) }), signal()));
});

test('oversized advertised length cancels without reading the body', async () => {
  let cancelled = false;
  const response = new Response(new ReadableStream({
    cancel() { cancelled = true; },
  }), { headers: { 'content-length': String(MAX_RESPONSE_BYTES + 1) } });
  await assert.rejects(readProviderJson(response, signal()));
  assert.equal(cancelled, true);
});

test('byte-sized chunks and split UTF-8 characters decode correctly without accumulating chunk objects', async () => {
  const data = { value: '😀'.repeat(1000) };
  const bytes = Buffer.from(JSON.stringify(data));
  let offset = 0;
  const response = new Response(new ReadableStream({
    pull(controller) {
      if (offset === bytes.length) controller.close();
      else controller.enqueue(bytes.subarray(offset, ++offset));
    },
  }));
  assert.deepEqual(await readProviderJson(response, signal()), data);
});

test('lying or missing length cannot bypass streamed limits; slow cancellation cannot hold the request', {
  timeout: 5000,
}, async () => {
  for (const headers of [{}, { 'content-length': '1' }]) {
    let cancelled = false;
    const response = new Response(new ReadableStream({
      start(controller) { controller.enqueue(new Uint8Array(MAX_RESPONSE_BYTES + 1)); },
      cancel() { cancelled = true; return new Promise(() => {}); },
    }), { headers });
    await assert.rejects(readProviderJson(response, signal()));
    assert.equal(cancelled, true);
    assert.equal(response.body.locked, false);
  }
});

test('real fetch decompression is limited by decoded bytes, not compressed content-length', async t => {
  const body = gzipSync(JSON.stringify({ value: 'x'.repeat(MAX_RESPONSE_BYTES + 1) }));
  assert.ok(body.length < MAX_RESPONSE_BYTES);
  const server = createServer((_req, res) => {
    res.writeHead(200, { 'content-encoding': 'gzip', 'content-length': body.length });
    res.end(body);
  });
  server.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const response = await fetch(`http://127.0.0.1:${server.address().port}`);
  await assert.rejects(readProviderJson(response, signal()));
});

test('aborting a stalled body releases its reader and pre-aborted failures stay observed', async () => {
  let cancelled = false;
  const response = new Response(new ReadableStream({ cancel() { cancelled = true; } }));
  const controller = new AbortController();
  const pending = readProviderJson(response, controller.signal);
  controller.abort(new DOMException('private-timeout-detail', 'TimeoutError'));
  await assert.rejects(pending, { name: 'TimeoutError' });
  assert.equal(cancelled, true);
  assert.equal(response.body.locked, false);
  await assert.rejects(withAbort(Promise.reject(new Error('private-detail')), controller.signal),
    { name: 'TimeoutError' });
});

test('empty, malformed and non-object JSON are rejected before caching', async () => {
  for (const body of [null, '', '{', 'null', '[]', 'true', new Uint8Array([0xff])]) {
    await assert.rejects(readProviderJson(new Response(body), signal()));
  }
});

test('LRU cache evicts by entry count without crossing user keys', () => {
  const cache = createSourceCache();
  cache.set('user-a:title', sources('private-a'));
  cache.set('user-b:title', sources('private-b'));
  for (let i = 0; i < MAX_CACHE_ENTRIES - 2; i++) cache.set(`other:${i}`, sources(`${i}`));
  assert.equal(decode(cache.get('user-a:title')).sources[0].url, 'https://files.example/private-a');
  cache.set('new:title', sources('new'));
  assert.equal(cache.get('user-b:title'), undefined);
  assert.ok(cache.get('user-a:title'));
  assert.equal(cache.stats().entries, MAX_CACHE_ENTRIES);
});

test('cache byte accounting survives eviction, replacement and oversized entries', () => {
  const cache = createSourceCache();
  const data = sources('x'.repeat(700000));
  const size = Buffer.byteLength(JSON.stringify(data));
  for (let i = 0; i < MAX_CACHE_ENTRIES; i++) {
    cache.set(`user:${i}`, data);
    assert.ok(cache.stats().bytes <= MAX_CACHE_BYTES);
  }
  assert.equal(cache.stats().entries, Math.floor(MAX_CACHE_BYTES / size));
  assert.equal(cache.get('user:0'), undefined);
  const before = cache.stats().bytes;
  cache.set(`user:${MAX_CACHE_ENTRIES - 1}`, sources());
  assert.equal(cache.stats().bytes, before - size + Buffer.byteLength(JSON.stringify(sources())));
  const retained = cache.stats();
  cache.set('too-large', sources('x'.repeat(MAX_RESPONSE_BYTES)));
  assert.equal(cache.get('too-large'), undefined);
  assert.deepEqual(cache.stats(), retained);
});

test('expiry removes private source bodies, negative entries, and earliest signed-link margin', () => {
  let time = Date.parse('2026-11-05T00:00:00Z');
  const cache = createSourceCache({ now: () => time });
  cache.set('signed', { sources: [
    { url: 'https://files.example/a', expires_at: new Date(time + 40000).toISOString() },
    { url: 'https://files.example/b', expires_at: new Date(time + 100000).toISOString() },
  ] });
  cache.set('empty', { sources: [] });
  cache.set('unknown-expiry', sources());
  time += 10000;
  assert.equal(cache.get('signed'), undefined);
  assert.equal(cache.stats().entries, 2);
  time += 20000;
  assert.equal(cache.get('empty'), undefined);
  assert.equal(cache.stats().entries, 1);
  time += 270000;
  assert.deepEqual(cache.stats(), { entries: 0, bytes: 0 });
});
