// Credentials are generated directly into memory and passed to the host through
// the child environment, never arguments, logs, source files or local .env.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { googleRequest, project, email, root } = require('./provision_deletion_runtime.cjs');
const backend = path.join(root, 'backend');
const reports = path.join(root, 'reports/account-deletion-rollout');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function main() {
  const mode = process.argv[2];
  if (!['--disabled', '--enable-worker', '--enable-deletion'].includes(mode)) throw Error('Choose a reviewed rollout stage.');
  const proof = JSON.parse(fs.readFileSync(path.join(reports, 'real-emulator-integration.json')));
  if (!proof.passed || !proof.workerBundleVerified || proof.apiBundleSha256 !== hash(path.join(backend, '.neon-build/index.mjs')) ||
      proof.workerBundleSha256 !== hash(path.join(backend, '.neon-build/accountcleanup/index.mjs'))) throw Error('Current deployable bundles lack matching real-emulator evidence.');
  if (mode !== '--disabled') {
    const browser = JSON.parse(fs.readFileSync(path.join(reports, 'browser-integration.json')));
    if (!browser.passed) throw Error('Passing real-browser deletion evidence is required.');
  }
  if (mode === '--enable-deletion') {
    const ready = JSON.parse(fs.readFileSync(path.join(reports, 'production-readiness.json')));
    if (!ready.workerScheduledRunVerified || !ready.publicChecksPassed || !ready.googleSignInVerified) {
      throw Error('A verified scheduled run, public access checks and real Google sign-in confirmation are required.');
    }
  }
  const request = await googleRequest();
  const web = await request(`https://firebase.googleapis.com/v1beta1/projects/${project}/webApps/1:609797109604:web:a31f4ccb96e9c978f12c71/config`);
  const page = require('../backend/deletion_page');
  if (web.status !== 200 || ['projectId', 'appId', 'apiKey', 'authDomain'].some(key => web.data[key] !== page.config[key])) {
    throw Error('The deletion page Firebase configuration does not match its registered web app.');
  }
  let credential;
  let createdKeyName;
  if (mode === '--disabled') {
    if (fs.existsSync(path.join(reports, 'runtime-key-metadata.json'))) {
      throw Error('A runtime key has already been issued. Inspect its hosted state and rotate deliberately rather than issuing another key.');
    }
    const key = await request(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/${email}/keys`, 'POST', {
      privateKeyType: 'TYPE_GOOGLE_CREDENTIALS_FILE', keyAlgorithm: 'KEY_ALG_RSA_2048',
    });
    if (key.status !== 200 || !key.data.privateKeyData) throw Error('Runtime credential issuance failed.');
    credential = Buffer.from(key.data.privateKeyData, 'base64').toString('utf8');
    const parsed = JSON.parse(credential);
    if (parsed.project_id !== project || parsed.client_email !== email) throw Error('Unexpected runtime credential identity.');
    createdKeyName = key.data.name;
    // Store the identifier for rotation/revocation, never the private key.
    fs.writeFileSync(path.join(reports, 'runtime-key-metadata.json'), JSON.stringify({ serviceAccount: email,
      keyName: createdKeyName, privateKeyStoredLocally: false, createdAtUtc: new Date().toISOString() }, null, 2) + '\n');
    const { initializeApp, cert, deleteApp } = require(require.resolve('firebase-admin/app', { paths: [backend] }));
    const { getAuth } = require(require.resolve('firebase-admin/auth', { paths: [backend] }));
    const { initializeFirestore } = require(require.resolve('firebase-admin/firestore', { paths: [backend] }));
    const app = initializeApp({ projectId: project, credential: cert(parsed) }, 'cleanup-readiness');
    const db = initializeFirestore(app, { preferRest: true });
    let ready = false;
    try {
      for (let attempt = 0; attempt < 12; attempt++) {
        try {
          await getAuth(app).getUserByEmail('ngetichezra609@gmail.com');
          await db.runTransaction(async tx => { await tx.get(db.doc('account_deletions/runtime-readiness-probe')); });
          await db.collection('account_deletions').where('status', '==', 'pending').limit(1).get();
          ready = true; break;
        } catch (_) { if (attempt < 11) await new Promise(resolve => setTimeout(resolve, 5000)); }
      }
      if (!ready) throw Error('Dedicated runtime read/transaction permissions did not become ready. The new key identifier is recorded for revocation.');
    } finally { await db.terminate(); await deleteApp(app); }
    console.log('Dedicated runtime Auth lookup and Firestore transaction/query access verified.');
  }
  const env = { ...process.env, ACCOUNT_DELETION_ENABLED: mode === '--enable-deletion' ? 'true' : 'false',
    ACCOUNT_DELETION_WORKER_ENABLED: mode === '--disabled' ? 'false' : 'true',
    ...(credential ? { FIREBASE_SERVICE_ACCOUNT_JSON: credential } : {}) };
  for (const stage of ['--plan', '--deploy']) {
    const run = spawnSync(process.execPath, ['scripts/deploy_neon.js', stage], { cwd: backend, env,
      encoding: 'utf8', windowsHide: true, timeout: 600000, maxBuffer: 16 * 1024 * 1024 });
    // Child output is already allowlisted/redacted; additionally avoid any raw
    // output if the private credential unexpectedly appears at all.
    const output = (run.stdout || '') + (run.stderr || '');
    if (credential && (output.includes(credential) || output.includes(JSON.parse(credential).private_key))) {
      throw Error('Deployment output failed credential redaction; raw output was suppressed.');
    }
    if (run.error || run.status !== 0) {
      const reasons = ['out of memory', 'heap out of memory', 'conflict', 'Unexpected plan target',
        'unrelated branch/deletion change', 'Access is denied', 'EPERM', 'spawn', 'not recognized',
        'Cannot find module', 'Invalid environment', 'No changes', 'not logged in', 'authentication', 'unknown option']
        .filter(reason=>output.toLowerCase().includes(reason.toLowerCase()));
      throw Error(`Neon ${stage} failed (exit ${run.status}; ${reasons.join(', ') || 'diagnostic output suppressed'}). No deletion feature was automatically enabled.`);
    }
    console.log(`Neon ${stage} completed successfully; private deployment output was not printed.`);
  }
  fs.writeFileSync(path.join(reports, 'last-deployment-stage.json'), JSON.stringify({ mode,
    accountDeletionEnabled: env.ACCOUNT_DELETION_ENABLED === 'true', workerEnabled: env.ACCOUNT_DELETION_WORKER_ENABLED === 'true',
    privateKeyStoredLocally: false, deployedAtUtc: new Date().toISOString() }, null, 2) + '\n');
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
