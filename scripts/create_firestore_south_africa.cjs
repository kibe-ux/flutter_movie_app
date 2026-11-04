// Explicitly authorized bootstrap for Movie Hub. Never changes an existing
// database's location or overwrites an existing non-bootstrap rules release.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
process.env.DEBUG = '';
const workspace = path.resolve(__dirname, '..');
const projectId = 'my-flutter-app-hezra-202-12dc9';
const locationId = 'africa-south1';
const databaseName = `projects/${projectId}/databases/(default)`;
const releaseName = `projects/${projectId}/releases/cloud.firestore`;
const firestore = 'https://firestore.googleapis.com/v1/';
const rulesApi = 'https://firebaserules.googleapis.com/v1/';
const source = fs.readFileSync(path.join(workspace, 'firestore.rules'), 'utf8');
const expected = "rules_version = '2';\nservice cloud.firestore {\n  match /databases/{database}/documents {\n    // Bootstrap policy: keep client access closed until feature rules are tested.\n    // Trusted Admin SDK access is controlled separately through Google Cloud IAM.\n    match /{document=**} {\n      allow read, write: if false;\n    }\n  }\n}\n";
if (source.replaceAll('\r\n', '\n') !== expected) throw new Error('Bootstrap rules changed; review before deployment.');
const directory = path.join(workspace, 'reports', 'firestore-security-2026-10-31');
const save = (name, data) => {
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, name), JSON.stringify(data, null, 2) + '\n');
};

async function main() {
  const plan = { projectId, databaseId: '(default)', locationId, type: 'FIRESTORE_NATIVE',
    databaseEdition: 'STANDARD', deleteProtectionState: 'DELETE_PROTECTION_ENABLED',
    clientAccess: 'deny all', billingPlanChange: false };
  console.log(JSON.stringify(plan));
  if (process.argv[2] !== '--apply') { console.log('Plan only. Pass --apply and the firebase-tools installation directory to provision.'); return; }
  if (!process.argv[3]) throw new Error('Pass the installed firebase-tools directory.');
  const auth = require(path.join(process.argv[3], 'lib', 'auth.js'));
  const account = auth.getProjectDefaultAccount(workspace);
  if (!account?.tokens?.refresh_token) throw new Error('No saved Firebase CLI login.');
  const tokens = await auth.getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase',
  ]);
  async function request(url, method = 'GET', body, allowMissing = false) {
    const response = await fetch(url, {
      method, headers: { Authorization: `Bearer ${tokens.access_token}`, 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(45000),
    });
    const data = await response.json();
    if (allowMissing && response.status === 404) return null;
    if (!response.ok) throw new Error(`Google API HTTP ${response.status}: ${data.error?.message || 'request failed'}`);
    return data;
  }
  let database = await request(firestore + databaseName, 'GET', undefined, true);
  if (database && (database.locationId !== locationId || database.type !== 'FIRESTORE_NATIVE')) {
    throw new Error('An existing database has a different region or mode. No changes made.');
  }
  let release = await request(rulesApi + releaseName, 'GET', undefined, true);
  if (release) {
    const existing = await request(rulesApi + release.rulesetName);
    if (existing.source?.files?.length !== 1 || existing.source.files[0].content.replaceAll('\r\n', '\n') !== expected) {
      throw new Error('An existing rules release is not this deny-all bootstrap. Refusing to overwrite it.');
    }
  }
  save('database-creation-plan.json', { ...plan, requestedAtUtc: new Date().toISOString() });
  if (!database) {
    let operation = await request(firestore + `projects/${projectId}/databases?databaseId=%28default%29`, 'POST', {
      locationId, type: plan.type, databaseEdition: plan.databaseEdition, deleteProtectionState: plan.deleteProtectionState,
    });
    const operationName = operation.name;
    save('database-creation-operation.json', operation);
    console.log('Johannesburg database creation accepted. Waiting for completion.');
    for (let poll = 0; !operation.done && poll < 90; poll++) {
      if (!operationName?.startsWith(databaseName + '/operations/')) throw new Error('Unexpected operation reference.');
      await new Promise((resolve) => setTimeout(resolve, 2000));
      operation = await request(firestore + operationName);
    }
    save('database-creation-operation.json', operation);
    if (!operation.done) throw new Error('Database creation is pending. Check the saved operation before retrying.');
    if (operation.error) throw new Error(`Database creation failed: ${operation.error.message}`);
    database = await request(firestore + databaseName);
  }
  if (database.locationId !== locationId || database.type !== plan.type) throw new Error('Database verification failed.');
  save('database-created.json', database);
  console.log(`Verified default database: ${database.locationId}, ${database.type}.`);
  if (!release) {
    const ruleset = await request(rulesApi + `projects/${projectId}/rulesets`, 'POST', {
      source: { files: [{ name: 'firestore.rules', content: source }] },
    });
    save('bootstrap-ruleset.json', ruleset);
    release = await request(rulesApi + `projects/${projectId}/releases`, 'POST', {
      name: releaseName, rulesetName: ruleset.name,
    });
  }
  const deployedRelease = await request(rulesApi + releaseName);
  const deployedRules = await request(rulesApi + deployedRelease.rulesetName);
  if (deployedRules.source?.files?.length !== 1 || deployedRules.source.files[0].content.replaceAll('\r\n', '\n') !== expected) {
    throw new Error('Deployed bootstrap source did not match the local policy.');
  }
  save('bootstrap-verification.json', { projectId, databaseName, locationId: database.locationId,
    type: database.type, deleteProtectionState: database.deleteProtectionState, clientAccess: 'deny all',
    releaseName: deployedRelease.name, rulesetName: deployedRelease.rulesetName,
    rulesSha256: crypto.createHash('sha256').update(source).digest('hex'), verifiedAtUtc: new Date().toISOString() });
  console.log('Verified deployed deny-all rules. No client reads or writes are allowed.');
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
