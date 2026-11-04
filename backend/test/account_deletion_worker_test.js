const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createDeletionWorker } = require('../account_deletion_worker');
const { runtimeOptions } = require('../firebase_runtime');

function invocation(changes = {}, headers = { 'x-neon-trigger-invocation-id': 'run1' }) {
  return new Request('https://worker.example/', { method: 'POST', headers,
    body: JSON.stringify({ invocation_id: 'run1', data: { scheduled_at: new Date().toISOString() }, ...changes }) });
}
test('retry worker rejects public calls and disabled deployment before privileged access', async () => {
  let accessed = false;
  const opts = { auth: () => { accessed = true; }, onNeon: () => true, enabled: () => false };
  const worker = createDeletionWorker(opts);
  assert.equal((await worker.fetch(invocation({}, {}))).status, 403);
  assert.equal((await worker.fetch(invocation())).status, 503);
  assert.equal((await createDeletionWorker({ ...opts, onNeon: () => false }).fetch(invocation())).status, 403);
  assert.equal(accessed, false);
});
test('trusted retry validates payload, logs no account identity and requests retry on failures', async () => {
  let fail = false, runs = 0;
  const logs = [];
  const worker = createDeletionWorker({ auth: () => ({}), onNeon: () => true, enabled: () => true,
    log: value => logs.push(value), service: () => ({ retryPending: async () => {
      runs++; if (fail) throw Error('private user identifier');
      return { jobsSeen: 0, completedJobs: 0, oldestPendingAgeMs: 0 };
    } }) });
  assert.equal((await worker.fetch(invocation({ invocation_id: 'wrong' }))).status, 400);
  assert.equal((await worker.fetch(invocation({ data: {} }))).status, 400);
  assert.equal(runs, 0);
  assert.equal((await worker.fetch(invocation())).status, 200);
  fail = true;
  const failed = await worker.fetch(invocation());
  assert.equal(failed.status, 503);
  assert.equal(failed.headers.get('retry-after'), '300');
  assert.equal(JSON.stringify(logs).includes('private user identifier'), false);
});
test('runtime credentials reject malformed or cross-project keys without exposing contents', () => {
  for (const value of ['private invalid credential', JSON.stringify({ type: 'service_account', project_id: 'wrong', private_key: 'private key' })]) {
    assert.throws(() => runtimeOptions({ FIREBASE_PROJECT_ID: 'expected', FIREBASE_SERVICE_ACCOUNT_JSON: value }),
      error => !error.message.includes(value) && !error.message.includes('private key'));
  }
});
