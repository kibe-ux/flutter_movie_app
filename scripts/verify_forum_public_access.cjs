// Live read checks only. Never creates test users or application documents and
// never displays public document contents, tokens or private data.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const reports = path.join(root, 'reports/firestore-security-2026-10-31');
const projectId = 'my-flutter-app-hezra-202-12dc9';
const origin = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/`;
async function main() {
  const deployment = JSON.parse(fs.readFileSync(path.join(reports, 'forum-deployment-verification.json'), 'utf8'));
  if (deployment.projectId !== projectId || !deployment.indexesReady || !deployment.emulatorTestsPassed) {
    throw new Error('Verified rules deployment is required before the live read checks.');
  }
  const checks = [];
  for (const [name, resource, expected] of [
    ['public forum feed', 'forum_posts?pageSize=1', 200],
    ['private reward wallet', 'reward_accounts/security-probe-missing', 403],
    ['private deletion job', 'account_deletions/security-probe-missing', 403],
    ['private moderation reports', 'forum_reports?pageSize=1', 403],
    ['private forum membership', 'forum_members/security-probe-missing', 403],
    ['private blocked users', 'forum_members/security-probe-missing/blocked?pageSize=1', 403],
    ['unknown collection', 'unknown/security-probe-missing', 403],
  ]) {
    let result;
    for (let attempt = 0; attempt < 20; attempt++) {
      const response = await fetch(origin + resource, { signal: AbortSignal.timeout(30000) });
      const data = await response.json();
      result = { name, expectedStatus: expected, httpStatus: response.status,
        ...(data.error ? { errorStatus: data.error.status } : {}) };
      if (result.httpStatus === expected && (expected !== 403 || result.errorStatus === 'PERMISSION_DENIED')) break;
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
    checks.push(result);
    console.log(`${name}: HTTP ${result.httpStatus}`);
  }
  const passed = checks.every((check) => check.httpStatus === check.expectedStatus &&
    (check.expectedStatus !== 403 || check.errorStatus === 'PERMISSION_DENIED'));
  fs.writeFileSync(path.join(reports, 'forum-live-read-checks.json'), JSON.stringify({ projectId,
    passed, authenticated: false, writesAttempted: false, checks, checkedAtUtc: new Date().toISOString() }, null, 2) + '\n');
  if (!passed) process.exitCode = 1;
}
main().catch(() => { console.error('Live read verification could not complete; no data was modified.'); process.exitCode = 1; });
