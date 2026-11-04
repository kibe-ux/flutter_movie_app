// Deploy only emulator-tested forum rules and the declared Firestore indexes.
// Never deletes indexes, changes billing/IAM or writes application documents.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { requireReadyIndexes } = require('./firestore_index_readiness.cjs');
process.env.DEBUG = '';
const root = path.resolve(__dirname, '..');
const reports = path.join(root, 'reports/firestore-security-2026-10-31');
const project = 'my-flutter-app-hezra-202-12dc9';
const database = `projects/${project}/databases/(default)`;
const releaseName = `projects/${project}/releases/cloud.firestore`;
const firestore = 'https://firestore.googleapis.com/v1/';
const rulesApi = 'https://firebaserules.googleapis.com/v1/';
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const hash = (value) => crypto.createHash('sha256').update(value).digest('hex');
const save = (name, data) => fs.writeFileSync(path.join(reports, name), JSON.stringify(data, null, 2) + '\n');
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
function indexShape(index) {
  return JSON.stringify({ queryScope: index.queryScope,
    fields: (index.fields || []).filter((field) => field.fieldPath !== '__name__') });
}

async function main() {
  const source = read('firestore.rules');
  const proof = JSON.parse(fs.readFileSync(path.join(reports, 'forum-rules-tests.json'), 'utf8'));
  if (!proof.passed || proof.rulesSha256 !== hash(source) ||
      proof.testsSha256 !== hash(read('tools/firestore-tests/forum_rules.test.cjs'))) {
    throw new Error('Current rules do not match passing emulator test evidence.');
  }
  const indexes = JSON.parse(read('firestore.indexes.json'));
  console.log(JSON.stringify({ project, database: '(default)', location: 'africa-south1',
    rulesSha256: hash(source), indexes: indexes.indexes, fieldOverrides: indexes.fieldOverrides }));
  if (process.argv[2] !== '--apply') { console.log('Plan only. Pass --apply and the firebase-tools directory to deploy.'); return; }
  if (!process.argv[3]) throw new Error('Pass the installed firebase-tools directory.');
  const auth = require(path.join(process.argv[3], 'lib/auth.js'));
  const account = auth.getProjectDefaultAccount(root);
  if (!account?.tokens?.refresh_token) throw new Error('No saved Firebase CLI login.');
  const tokens = await auth.getAccessToken(account.tokens.refresh_token,
    ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']);
  async function request(url, method = 'GET', body) {
    const response = await fetch(url, { method, headers: { Authorization: 'Bearer ' + tokens.access_token,
      'Content-Type': 'application/json' }, ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      signal: AbortSignal.timeout(45000) });
    const data = await response.json();
    if (!response.ok) throw new Error(`Google API HTTP ${response.status}: ${data.error?.message || 'request failed'}`);
    return data;
  }
  async function operation(result) {
    const name = result.name;
    if (!name?.startsWith(database + '/operations/')) throw new Error('Unexpected Firestore operation reference.');
    for (let attempt = 0; !result.done && attempt < 300; attempt++) {
      await delay(2000);
      result = await request(firestore + name);
      if (attempt > 0 && attempt % 30 === 0 && !result.done) console.log('Waiting for Google to finish the index operation.');
    }
    if (!result.done) throw new Error('An index operation is still pending. Recheck before retrying.');
    if (result.error) throw new Error(result.error.message);
  }
  const db = await request(firestore + database);
  if (db.locationId !== 'africa-south1' || db.type !== 'FIRESTORE_NATIVE') throw new Error('Unexpected database location or mode.');
  const originalRelease = await request(rulesApi + releaseName);
  const originalRules = await request(rulesApi + originalRelease.rulesetName);
  const bootstrap = JSON.parse(fs.readFileSync(path.join(reports, 'bootstrap-verification.json'), 'utf8'));
  const deployedHash = originalRules.source?.files?.length === 1 ? hash(originalRules.source.files[0].content) : '';
  const previous = JSON.parse(fs.readFileSync(path.join(reports, 'forum-deployment-verification.json'), 'utf8'));
  const previousHash = previous.projectId === project && previous.database === database &&
    previous.indexesReady === true && previous.emulatorTestsPassed === true
    ? previous.rulesSha256 : '';
  if (![bootstrap.rulesSha256, previousHash, hash(source)].includes(deployedHash)) throw new Error('Deployed rules changed outside this reviewed rollout. Refusing to overwrite.');
  save('pre-forum-release.json', originalRelease);
  save('pre-forum-rules.json', originalRules);

  const verifiedIndexes = [];
  for (const desired of indexes.indexes || []) {
    const url = firestore + database + '/collectionGroups/' + encodeURIComponent(desired.collectionGroup) + '/indexes';
    const existing = [];
    let pageToken;
    do {
      const page = await request(url + (pageToken ? '?pageToken=' + encodeURIComponent(pageToken) : ''));
      existing.push(...(page.indexes || []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    let current = existing.find((index) => indexShape(index) === indexShape(desired));
    if (!current) {
      console.log('Creating required index for ' + desired.collectionGroup + '.');
      await operation(await request(url, 'POST', { queryScope: desired.queryScope, fields: desired.fields }));
      current = (await request(url)).indexes?.find((index) => indexShape(index) === indexShape(desired));
    }
    for (let attempt = 0; current?.state === 'CREATING' && attempt < 300; attempt++) {
      if (attempt % 30 === 0) console.log('Waiting for the existing composite index to become READY.');
      await delay(2000);
      current = await request(firestore + current.name);
    }
    if (current?.state !== 'READY') throw new Error('Required composite index is not READY.');
    verifiedIndexes.push(current);
  }
  const verifiedFields = [];
  for (const desired of indexes.fieldOverrides || []) {
    const url = firestore + database + '/collectionGroups/' + encodeURIComponent(desired.collectionGroup) + '/fields/' + encodeURIComponent(desired.fieldPath);
    const wanted = desired.indexes.map((index) => ({ queryScope: index.queryScope,
      fields: [{ fieldPath: desired.fieldPath, ...(index.order ? { order: index.order } : { arrayConfig: index.arrayConfig }) }] }));
    const existing = await request(url);
    const matches = () => wanted.every((index) => (existing.indexConfig?.indexes || [])
      .some((current) => indexShape(current) === indexShape(index)));
    if (!matches()) {
      console.log('Configuring required field indexes for ' + desired.collectionGroup + '.' + desired.fieldPath + '.');
      await operation(await request(url + '?updateMask=indexConfig', 'PATCH', { indexConfig: { indexes: wanted } }));
    }
    let current = await request(url);
    for (let attempt = 0; (current.indexConfig?.indexes || []).some((index) => index.state === 'CREATING') && attempt < 300; attempt++) {
      if (attempt % 30 === 0) console.log('Waiting for field indexes to become READY.');
      await delay(2000);
      current = await request(url);
    }
    if (!wanted.every((index) => (current.indexConfig?.indexes || []).some((value) =>
      indexShape(value) === indexShape(index) && value.state === 'READY'))) throw new Error('Required field indexes are not READY.');
    verifiedFields.push(current);
  }
  save('forum-ready-indexes.json', { indexes: verifiedIndexes, fields: verifiedFields });
  console.log('Required indexes are READY.');
  if (deployedHash !== hash(source)) {
    // Re-read all index resources immediately before rules publication. The
    // polling loops above never grant permission to publish by themselves.
    const freshIndexes = [];
    for (const index of verifiedIndexes) freshIndexes.push(await request(firestore + index.name));
    const freshFields = [];
    for (const field of verifiedFields) freshFields.push(await request(firestore + field.name));
    requireReadyIndexes(freshIndexes, freshFields,
      (indexes.indexes || []).length, (indexes.fieldOverrides || []).length);
    const ruleset = await request(rulesApi + `projects/${project}/rulesets`, 'POST', {
      source: { files: [{ name: 'firestore.rules', content: source }] },
    });
    save('forum-ruleset.json', ruleset);
    const latest = await request(rulesApi + releaseName);
    if (latest.rulesetName !== originalRelease.rulesetName) throw new Error('Rules release changed during deployment. Refusing to overwrite.');
    await request(rulesApi + releaseName, 'PATCH', { release: { name: releaseName, rulesetName: ruleset.name } });
  }
  const release = await request(rulesApi + releaseName);
  const deployed = await request(rulesApi + release.rulesetName);
  if (deployed.source?.files?.length !== 1 || hash(deployed.source.files[0].content) !== hash(source)) throw new Error('Deployed source differs from tested rules.');
  save('forum-deployment-verification.json', { projectId: project, database: database,
    locationId: db.locationId, release: release, rulesSha256: hash(source), indexesReady: true,
    emulatorTestsPassed: true, verifiedAtUtc: new Date().toISOString() });
  console.log('Verified deployed forum rules match the passing emulator tests.');
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
