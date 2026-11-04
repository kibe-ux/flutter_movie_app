const test = require('node:test');
const assert = require('node:assert/strict');
const { createWambeshaLimits } = require('../wambesha_limits');

const { memoryRateStore } = require('../test_support/memory_rate_store');

test('shared clients, source quotas and global budgets span limiter instances', async () => {
  const store = memoryRateStore();
  let now = 1000;
  const options = { store, now: () => now, clientLimit: 2, sourceLimit: 1, upstreamLimit: 2 };
  const a = createWambeshaLimits(options), b = createWambeshaLimits(options);
  await a.client('private-user'); await b.client('private-user');
  await assert.rejects(a.client('private-user'), { status: 429, retryAfter: 59 });
  await a.source('private-user');
  await assert.rejects(b.source('private-user'), { status: 429 });
  await b.source('different-user');
  await a.upstream(); await b.upstream();
  await assert.rejects(a.upstream(), { status: 503 });
  assert.doesNotMatch([...store.buckets.keys()].join(), /private-user|different-user/);
  now = 60001;
  await b.client('private-user'); await a.source('private-user'); await b.upstream();
});

test('a limiter database outage fails closed with a safe retry hint', async () => {
  const limits = createWambeshaLimits({ store: {
    consume: async () => { throw new Error('postgresql://secret-password'); },
  } });
  for (const action of [() => limits.client('viewer'), () => limits.source('viewer'), () => limits.upstream()]) {
    await assert.rejects(action(), error => {
      assert.equal(error.status, 503); assert.equal(error.retryAfter, 15);
      assert.doesNotMatch(error.message, /postgresql|secret/); return true;
    });
  }
});
