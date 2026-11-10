// Feed server JSON logs on stdin. No provider or database calls are made.
const readline = require('node:readline');
const counts = {
  upstreamRequests: 0, sourceRequests: 0, localCacheHits: 0,
  coalescedRequests: 0, sharedCacheHits: 0, sourceErrors: 0,
  reportedVerifications: 0, unknownVerificationResponses: 0,
};
const lines = readline.createInterface({ input: process.stdin });
lines.on('line', line => {
  let row;
  try { row = JSON.parse(line); } catch { return; }
  if (row.component !== 'wambesha-usage') return;
  if (row.event === 'upstream-request') {
    counts.upstreamRequests++;
    if (row.sources) counts.sourceRequests++;
  }
  if (row.event === 'cache-hit') counts.localCacheHits++;
  if (row.event === 'coalesced') counts.coalescedRequests++;
  if (row.event === 'shared-cache' && ['SHARED_HIT', 'SHARED_COALESCED'].includes(row.cache)) counts.sharedCacheHits++;
  if (row.event === 'source-error') counts.sourceErrors++;
  if (row.event === 'verification') {
    if (row.spent === 0 || row.spent === 1) counts.reportedVerifications += row.spent;
    else counts.unknownVerificationResponses++;
  }
});
lines.on('close', () => process.stdout.write(`${JSON.stringify(counts, null, 2)}\n`));
