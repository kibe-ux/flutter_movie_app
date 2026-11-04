// Enables only the Firestore API. Does not create databases or change billing,
// rules, IAM, indexes, or application data. Uses an existing Firebase CLI login.
const fs = require('node:fs');
const path = require('node:path');
process.env.DEBUG = '';
const workspace = path.resolve(__dirname, '..');
const cliRoot = process.argv[2];
if (!cliRoot) throw new Error('Pass the installed firebase-tools directory.');
const auth = require(path.join(cliRoot, 'lib', 'auth.js'));
const projectId = 'my-flutter-app-hezra-202-12dc9';
const serviceName = `projects/${projectId}/services/firestore.googleapis.com`;
const origin = 'https://serviceusage.googleapis.com/v1/';

async function main() {
  const account = auth.getProjectDefaultAccount(workspace);
  if (!account?.tokens?.refresh_token) throw new Error('No saved Firebase CLI login.');
  const tokens = await auth.getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/firebase',
  ]);
  // Headers/tokens never appear in logs or exported files.
  async function request(resource, method = 'GET') {
    const response = await fetch(origin + resource, {
      method,
      headers: { Authorization: `Bearer ${tokens.access_token}` },
      signal: AbortSignal.timeout(45000),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(`Service Usage HTTP ${response.status}: ${data.error?.message || 'request failed'}`);
    return data;
  }
  const initial = await request(serviceName);
  console.log(`Firestore API initial state: ${initial.state}`);
  if (initial.state !== 'ENABLED') {
    let operation = await request(serviceName + ':enable', 'POST');
    const operationName = operation.name;
    console.log('Firestore API enable request accepted. Waiting for completion.');
    for (let poll = 0; !operation.done && poll < 30; poll++) {
      if (!/^operations\/[a-zA-Z0-9._/-]+$/.test(operationName || '')) {
        throw new Error('Unexpected operation reference.');
      }
      await new Promise((resolve) => setTimeout(resolve, 2000));
      operation = await request(operationName);
    }
    if (!operation.done) throw new Error('Enable operation is still pending; check service state before retrying.');
    if (operation.error) throw new Error(`Enable operation failed: ${operation.error.message}`);
  }
  const result = await request(serviceName);
  const report = { projectId, service: 'firestore.googleapis.com', initialState: initial.state,
    state: result.state, checkedAtUtc: new Date().toISOString() };
  const directory = path.join(workspace, 'reports', 'firestore-security-2026-10-31');
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'api-enablement.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(`Firestore API verified state: ${result.state}`);
  if (result.state !== 'ENABLED') process.exitCode = 1;
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
