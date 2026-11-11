const test = require('node:test');
const assert = require('node:assert/strict');
const { createWambeshaBudget, createBudgetStore, periods } = require('../wambesha_budget');

function memoryBudgetStore() {
  const rows = new Map(), events = [];
  return { rows, events,
    async reserve(scope, buckets, initialUsage = {}) {
      const row = rows.get(scope) || Object.fromEntries(buckets.map(([column, period]) =>
        [column, { period, used: initialUsage[column] || 0 }]));
      const next = { ...row };
      for (const [column, period, units, limit] of buckets) {
        const used = row[column]?.period === period ? row[column].used : 0;
        if (units && used + units > limit) return false;
        next[column] = { period, used: used + units };
      }
      rows.set(scope, next); return true;
    },
    async record(scope, period, event, count) { events.push({ scope, period, event, count }); },
    async report(scope) { return { reservations: rows.get(scope), events }; },
  };
}

test('concurrent instances reserve without exceeding the monthly source budget', async () => {
  const store = memoryBudgetStore();
  const options = { store, callMonth: 100, sourceMonth: 3, callDay: 100, sourceDay: 100 };
  const a = createWambeshaBudget(options), b = createWambeshaBudget(options);
  const results = await Promise.allSettled(Array.from({ length: 20 }, (_, i) => (i % 2 ? a : b).reserve(true)));
  assert.equal(results.filter(row => row.status === 'fulfilled').length, 3);
  assert.equal(store.rows.get('default').call_month.used, 3, 'rejected reservations consume neither meter');
  await a.reserve(false);
  assert.equal(store.rows.get('default').call_month.used, 4, 'metadata still works when sources are exhausted');
});

test('daily and monthly windows reset separately with paid billing-day support', async () => {
  let now = Date.UTC(2026, 10, 20, 23, 59);
  const store = memoryBudgetStore();
  const budget = createWambeshaBudget({ store, now: () => now, billingDay: 15,
    callMonth: 4, sourceMonth: 2, callDay: 2, sourceDay: 1 });
  await budget.reserve(true);
  await assert.rejects(budget.reserve(true), { status: 503 });
  now = Date.UTC(2026, 10, 21);
  await budget.reserve(true);
  now = Date.UTC(2026, 11, 1);
  await assert.rejects(budget.reserve(true), { status: 503 });
  await budget.reserve(false);
  now = Date.UTC(2026, 11, 15);
  await budget.reserve(true);
  assert.equal(store.rows.get('default').source_month.used, 1);
  assert.equal(periods(Date.UTC(2027, 1, 28), 31).verificationMonth, '2027-02-28');
});

test('zero limits stop new source calls and database errors fail closed', async () => {
  const budget = createWambeshaBudget({ store: memoryBudgetStore(), sourceMonth: 0 });
  await assert.rejects(budget.reserve(true), { status: 503 });
  await budget.reserve(false);
  const offline = createWambeshaBudget({ store: { reserve: async () => { throw Error('secret-password'); } } });
  await assert.rejects(offline.reserve(), error => error.status === 503 && !error.message.includes('secret'));
});

test('initial dashboard usage is applied once and is not reapplied by another instance', async () => {
  const store = memoryBudgetStore();
  const options = { store, sourceMonth: 3, initialUsage: { source_month: 2 } };
  await createWambeshaBudget(options).reserve(true);
  await assert.rejects(createWambeshaBudget(options).reserve(true), { status: 503 });
  assert.equal(store.rows.get('default').source_month.used, 3);
});

test('durable reporting distinguishes reservations, actual spends, hits and unknown results', async () => {
  const budget = createWambeshaBudget({ store: memoryBudgetStore() });
  await budget.reserve(true);
  await budget.record('cache-hit');
  await budget.record('metadata-cache-hit');
  await budget.record('verification', { spent: 1 });
  await budget.record('verification', { spent: null });
  const report = await budget.report();
  assert.deepEqual(report.events.map(row => row.event), ['source_cache_hits', 'metadata_cache_hits',
    'reported_verifications', 'unknown_verification_responses']);
});

test('SQL store uses one conditional UPDATE for all meters and retains counters outside rate cleanup', async () => {
  const queries = [];
  const store = createBudgetStore({ query: async (sql, params) => {
    queries.push({ sql, params }); return sql.startsWith('UPDATE') ? [{ scope: 'default' }] : [];
  } });
  assert.equal(await store.reserve('default', [
    ['call_month', '2026-11', 1, 45000], ['source_month', '2026-11-01', 1, 900],
    ['call_day', '2026-11-11', 1, 9000], ['source_day', '2026-11-11', 1, 180],
  ]), true);
  const update = queries.find(row => row.sql.startsWith('UPDATE'));
  assert.equal((update.sql.match(/ <= /g) || []).length, 8, 'periods cannot regress and all limits are guarded');
  assert.equal(update.params.length, 13);
  assert.ok(queries.every(row => !/catalogue_limits|DELETE/.test(row.sql)));
});

module.exports = { memoryBudgetStore };
