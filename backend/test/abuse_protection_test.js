const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createAbuseProtection } = require('../abuse_protection');
const { memoryRateStore } = require('../test_support/memory_rate_store');
function response() {
  return { statusCode: 200, headers: {}, set(k, v) { this.headers[k] = v; return this; },
    status(v) { this.statusCode = v; return this; }, json(body) { this.body = body; return this; } };
}
const request = (path = '/catalogue/3/movie/popular', headers = {}) => ({ path,
  socket: { remoteAddress: '127.0.0.1' }, header: key => headers[key] });
test('network quota spans instances and cannot be reset with installation or forwarding headers', async () => {
  const store = memoryRateStore();
  const instances = [createAbuseProtection({ store, now: () => 1000 }), createAbuseProtection({ store, now: () => 1000 })];
  let accepted = 0;
  for (let i = 0; i < 601; i++) {
    const res = response();
    await instances[i % 2].ingress(request(undefined, { 'X-MovieHub-Installation': String(i), 'X-Forwarded-For': String(i) }), res, () => accepted++);
    if (i === 600) { assert.equal(res.statusCode, 429); assert.equal(res.headers['Retry-After'], '59'); }
  }
  assert.equal(accepted, 600);
});
test('database outages fail closed', async () => {
  const protection = createAbuseProtection({ store: { consume() { throw Error('secret'); } } });
  const res = response();
  await protection.ingress(request(), res, () => assert.fail('must reject'));
  assert.equal(res.statusCode, 503);
  assert.ok(!JSON.stringify(res.body).includes('secret'));
});
test('enforced App Check rejects missing/invalid tokens and accepts verified tokens', async () => {
  const protection = createAbuseProtection({ store: {}, enforce: () => true,
    verify: async token => { if (token !== 'valid') throw Error('invalid'); } });
  for (const token of [undefined, 'bad', 'valid']) {
    const res = response(); let accepted = false;
    await protection.appCheck(request('/movies', { 'X-Firebase-AppCheck': token }), res, () => { accepted = true; });
    assert.equal(accepted, token === 'valid');
    assert.equal(res.statusCode, token === 'valid' ? 200 : 401);
  }
});
test('signed SSV, bearer streams and browser deletion remain available with App Check enforced', async () => {
  const protection = createAbuseProtection({ store: {}, enforce: () => true });
  for (const path of ['/rewards/ssv', '/account', '/download/stream']) {
    let accepted = false;
    await protection.appCheck(request(path), response(), () => { accepted = true; });
    assert.equal(accepted, true);
  }
});
test('account limits apply across endpoints and reset next minute', async () => {
  let now = 1000; const store = memoryRateStore();
  const protection = createAbuseProtection({ store, now: () => now });
  let accepted = 0;
  for (let i = 0; i < 61; i++) {
    const res = response();
    await protection.account({ path: '/api/rewards/' + i, firebaseUser: { uid: 'alice' } }, res, () => accepted++);
    if (i === 60) assert.equal(res.statusCode, 429);
  }
  assert.equal(accepted, 60);
  now = 60000;
  await protection.account({ path: '/api/rewards/daily', firebaseUser: { uid: 'alice' } }, response(), () => accepted++);
  assert.equal(accepted, 61);
});

test('account deletion has a separate five-request budget', async () => {
  const protection = createAbuseProtection({ store: memoryRateStore(), now: () => 1000 });
  let accepted = 0;
  for (let i = 0; i < 6; i++) {
    const res = response();
    await protection.account({ path: '/api/account', firebaseUser: { uid: 'alice' } }, res, () => accepted++);
    if (i === 5) assert.equal(res.statusCode, 429);
  }
  assert.equal(accepted, 5);
});
