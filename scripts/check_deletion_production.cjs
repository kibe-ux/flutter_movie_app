const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const backend = path.join(root, 'backend');
const reportPath = path.join(root, 'reports/account-deletion-rollout/production-readiness.json');
const target = ['--project-id', 'summer-shadow-58564268', '--branch', 'br-empty-forest-b4htkwt9'];
function neon(args) {
  const run = spawnSync(process.execPath, ['node_modules/neon/dist/cli.js', ...args, ...target, '-o', 'json'],
    { cwd: backend, encoding: 'utf8', windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  if (run.status !== 0) throw Error('Neon metadata request failed; raw output suppressed.');
  return JSON.parse(run.stdout);
}
async function main() {
  const functions = {};
  for (const slug of ['moviehub', 'accountcleanup']) {
    const raw = neon(['functions', 'get', slug]);
    const info = raw.function || raw;
    functions[slug] = { url: info.invocation_url, deploymentId: info.active_deployment?.id,
      status: info.active_deployment?.status };
  }
  const base = functions.moviehub.url;
  const health = await fetch(new URL('/health', base));
  const page = await fetch(new URL('/delete-account', base));
  const html = await page.text();
  const stage = JSON.parse(fs.readFileSync(path.join(root, 'reports/account-deletion-rollout/last-deployment-stage.json')));
  const deletionEnabled = !html.includes('Automatic deletion is being prepared.');
  const module = await fetch(new URL('/delete-account.js', base));
  const js = await module.text();
  const unauthenticated = await fetch(new URL('/api/account', base), { method: 'DELETE' });
  const workerPublic = await fetch(functions.accountcleanup.url, { method: 'POST', body: '{}' });
  const workerForged = await fetch(functions.accountcleanup.url, { method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Neon-Trigger-Invocation-Id': 'forged-invocation' },
    body: JSON.stringify({ invocation_id: 'forged-invocation', data: { scheduled_at: new Date().toISOString() } }) });
  const checks = { healthStatus: health.status, pageStatus: page.status, moduleStatus: module.status,
    deletionEnabled, deletionFlagMatchesStage: deletionEnabled === stage.accountDeletionEnabled,
    hasCsp: !!page.headers.get('content-security-policy'),
    googleScriptAllowed: page.headers.get('content-security-policy')?.includes('https://apis.google.com') || false,
    correctWebApp: js.includes('1:609797109604:web:a31f4ccb96e9c978f12c71'),
    noPrivateCredential: !/BEGIN PRIVATE KEY|private_key_id|service_account/.test(html + js),
    noEmulatorOrigin: !/127\.0\.0\.1:9098|localhost:9098/.test(js),
    unauthenticatedStatus: unauthenticated.status,
    publicWorkerStatus: workerPublic.status, forgedWorkerStatus: workerForged.status };
  const passed = checks.deletionFlagMatchesStage && checks.healthStatus === 200 && checks.pageStatus === 200 && checks.moduleStatus === 200 && checks.hasCsp && checks.googleScriptAllowed &&
    checks.correctWebApp && checks.noPrivateCredential && checks.noEmulatorOrigin &&
    checks.unauthenticatedStatus === 401 && checks.publicWorkerStatus === 403 && checks.forgedWorkerStatus === 403;
  const prior = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath)) : {};
  fs.writeFileSync(reportPath, JSON.stringify({ ...prior, checkedAtUtc: new Date().toISOString(),
    functions, checks, publicChecksPassed: passed,
    workerScheduledRunVerified: prior.workerScheduledRunVerified || false,
    googleSignInVerified: prior.googleSignInVerified || false }, null, 2) + '\n');
  console.log(JSON.stringify({ functions, checks, publicChecksPassed: passed }, null, 2));
  if (!passed) process.exitCode = 1;
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
