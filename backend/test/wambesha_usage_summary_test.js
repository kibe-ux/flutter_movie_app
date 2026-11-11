const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

test('log summary separates provider-reported charges from unknown responses', () => {
  const rows = [
    { event: 'upstream-request', sources: true },
    { event: 'upstream-request', sources: false },
    { event: 'cache-hit' }, { event: 'coalesced' },
    { event: 'shared-cache', cache: 'SHARED_HIT' },
    { event: 'verification', spent: 1 }, { event: 'verification', spent: 0 },
    { event: 'verification', spent: null }, { event: 'source-error' },
    { event: 'metadata-cache-hit' }, { event: 'quota-rejected' }, { event: 'reporting-error' },
  ].map(row => JSON.stringify({ component: 'wambesha-usage', ...row }));
  const result = spawnSync(process.execPath,
    [path.join(__dirname, '../scripts/summarize_wambesha_usage.js')],
    { input: ['non-JSON log', ...rows].join('\n'), encoding: 'utf8' });
  assert.equal(result.status, 0);
  assert.deepEqual(JSON.parse(result.stdout), {
    upstreamRequests: 2, sourceRequests: 1, localCacheHits: 1,
    coalescedRequests: 1, sharedCacheHits: 1, sourceErrors: 1,
    reportedVerifications: 1, unknownVerificationResponses: 1,
    metadataCacheHits: 1, quotaRejections: 1, reportingErrors: 1,
  });
});
