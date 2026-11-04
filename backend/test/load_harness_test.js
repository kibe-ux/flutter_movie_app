const test = require('node:test');
const assert = require('node:assert/strict');
const { options, percentile, run } = require('../load/run');

test('load runner rejects remote targets and unsafe database probes', () => {
  for (const args of [
    ['--url=https://example.com'], ['--rate=2001'], ['--duration=61'],
    ['--store=neon'], ['--store=neon', '--concurrency=20', '--rate=21'],
    ['--store=neon', '--concurrency=20', '--rate=10', '--profile=capacity'],
  ]) assert.throws(() => options(args));
  assert.equal(options(['--store=neon', '--rate=10', '--concurrency=20']).store, 'neon');
});

test('latency percentiles use the nearest rank and handle empty samples', () => {
  assert.equal(percentile([], .95), null);
  assert.equal(percentile([100, 2, 9, 1], .95), 100);
  assert.equal(percentile([100, 2, 9, 1], .5), 2);
});

test('load fixture serves warmed real routes and shuts down cleanly', { timeout: 20000 }, async () => {
  const report = await run(options(['--rate=20', '--duration=1', '--provider-latency=0']));
  assert.equal(report.load.scheduled, 20);
  assert.equal(report.load.successful, 20);
  assert.equal(report.load.generatorDropped, 0);
  assert.deepEqual(report.server.providerCalls, { tmdb: 0, wambesha: 0 });
  assert.equal(report.server.storeCalls.consume, 20);
  assert.equal(report.storeCleanupSucceeded, true);
});
