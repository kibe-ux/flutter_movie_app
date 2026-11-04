const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const file = path.join(root, 'reports/account-deletion-rollout/production-readiness.json');
function query(args) {
  const run = spawnSync(process.execPath, ['node_modules/neon/dist/cli.js', ...args,
    '--project-id', 'summer-shadow-58564268', '--branch', 'br-empty-forest-b4htkwt9', '-o', 'json'],
  { cwd: path.join(root, 'backend'), encoding: 'utf8', windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  if (run.status !== 0) throw Error('Scheduler metadata/log query failed; raw output suppressed.');
  return JSON.parse(run.stdout);
}
try {
  const raw = query(['triggers', 'list']);
  const list = Array.isArray(raw) ? raw : (raw.triggers || []);
  const triggers = list.filter(t => t.function_slug === 'accountcleanup').map(t => ({
    name: t.name, enabled: t.enabled, schedule: t.schedule, nextRunAt: t.next_run_at }));
  const logs = query(['logs', 'query', '--since', '15m', '--source', 'function',
    '--body-contains', 'account-deletion-retry', '--limit', '100']);
  const records = Array.isArray(logs) ? logs : (logs.records || logs.logs || []);
  const events = records.flatMap(record => {
    try {
      const value = JSON.parse(record.message);
      if (value.event !== 'account-deletion-retry') return [];
      return [{ timestamp: record.timestamp, service: record.service_name, ok: value.ok,
        jobsSeen: value.jobsSeen, completedJobs: value.completedJobs,
        purgedFences: value.purgedFences, oldestPendingAgeMs: value.oldestPendingAgeMs }];
    } catch (_) { return []; }
  });
  const ready = JSON.parse(fs.readFileSync(file));
  const stage = JSON.parse(fs.readFileSync(path.join(root, 'reports/account-deletion-rollout/last-deployment-stage.json')));
  const verified = triggers.some(t => t.enabled && t.schedule?.cron === '*/5 * * * *') &&
    events.some(event => event.ok && Date.parse(event.timestamp) >= Date.parse(stage.deployedAtUtc));
  fs.writeFileSync(file, JSON.stringify({ ...ready, schedulerCheckedAtUtc: new Date().toISOString(),
    triggers, schedulerEvents: events, workerScheduledRunVerified: ready.workerScheduledRunVerified || verified }, null, 2) + '\n');
  console.log(JSON.stringify({ triggers, events, workerScheduledRunVerified: verified }, null, 2));
} catch (error) { console.error(error.message); process.exitCode = 1; }
