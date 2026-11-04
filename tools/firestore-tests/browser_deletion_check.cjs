// Real browser flow against disposable demo emulator accounts only. Passwords
// and ID tokens stay inside the test process / local browser and are not logged.
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { spawn } = require('node:child_process');
const assert = require('node:assert/strict');
const { createDeletionPage } = require('../../backend/deletion_page');
const { registerAccountDeletionRoutes } = require('../../backend/account_deletion');
const backend = path.resolve(__dirname, '../../backend');
const express = require(require.resolve('express', { paths: [backend] }));
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function browserDeletionCheck({ auth, db, password }) {
  assert.equal(process.env.FIREBASE_PROJECT_ID, 'demo-moviehub-deletion');
  const uid = 'deletion-browser-test';
  await auth.createUser({ uid, email: `${uid}@example.test`, password });
  await db.doc(`users/${uid}/saved/title`).set({ saved: true });
  const page = createDeletionPage({ firebaseConfig: { apiKey: 'emulator-only', authDomain: 'localhost',
    projectId: 'demo-moviehub-deletion', appId: '1:123456:web:emulator' }, authEmulatorUrl: 'http://127.0.0.1:9098' });
  const app = express();
  let deleteCalls = 0;
  app.use(express.json());
  // Test-only local pages permit the local emulator origin. Production CSP is
  // separately checked on the deployed URL; it must not allow localhost.
  app.get('/delete-account', (_req, res) => res.type('html').send(page.html));
  app.get('/delete-account.js', (_req, res) => res.type('application/javascript').send(page.script));
  app.use((req, _res, next) => { if (req.method === 'DELETE') deleteCalls++; next(); });
  registerAccountDeletionRoutes(app, { page: page.html, enabled: () => true, firebaseAuth: () => auth,
    authenticate: async (req, res, next) => {
      try { req.firebaseUser = await auth.verifyIdToken((req.header('authorization') || '').replace(/^Bearer /, ''), true); next(); }
      catch (_) { res.sendStatus(401); }
    } });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const reserve = net.createServer();
  await new Promise(resolve => reserve.listen(0, '127.0.0.1', resolve));
  const port = reserve.address().port;
  await new Promise(resolve => reserve.close(resolve));
  const profile = path.join(__dirname, '.emulator/deletion-browser-profile');
  const executable = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const browser = spawn(executable, ['--headless=new', '--disable-gpu', '--disable-background-networking',
    '--disable-extensions', '--no-first-run', '--no-default-browser-check', '--disable-sync',
    '--remote-debugging-address=127.0.0.1', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank'],
  { windowsHide: true, stdio: 'ignore' });
  let socket, nextId = 0;
  const pending = new Map();
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++nextId;
    const timeout = setTimeout(() => { pending.delete(id); reject(Error('Browser command timed out')); }, 20000);
    pending.set(id, { resolve, reject, timeout });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const result = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw Error('Browser script evaluation failed');
    return result.result?.value;
  };
  const waitFor = async expression => {
    for (let n = 0; n < 100; n++) { if (await evaluate(expression)) return; await delay(200); }
    throw Error('Browser flow did not reach its expected state');
  };
  const verify = async value => {
    await evaluate(`document.getElementById('email').value=${JSON.stringify(`${uid}@example.test`)};document.getElementById('password').value=${JSON.stringify(value)};document.getElementById('email-form').requestSubmit();`);
  };
  try {
    let target;
    for (let n = 0; n < 100; n++) {
      if (browser.exitCode !== null) throw Error('Chrome exited before the browser test started');
      try {
        const response = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(origin + '/delete-account')}`, { method: 'PUT' });
        if (response.ok) { target = await response.json(); break; }
      } catch (_) { /* Browser startup. */ }
      await delay(200);
    }
    if (!target) throw Error('Chrome debugging endpoint did not start');
    socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
    socket.addEventListener('message', event => {
      const data = JSON.parse(event.data);
      if (!pending.has(data.id)) return;
      const item = pending.get(data.id); pending.delete(data.id); clearTimeout(item.timeout);
      if (data.error) item.reject(Error('Browser protocol command failed')); else item.resolve(data.result);
    });
    await waitFor(`document.getElementById('status')?.textContent === 'Choose your account sign-in method.'`);
    await verify('intentionally-wrong-password');
    await waitFor(`document.getElementById('status').textContent.startsWith('Could not verify')`);
    assert.equal(deleteCalls, 0);
    assert.equal((await auth.getUser(uid)).uid, uid);
    await verify(password);
    await waitFor(`document.getElementById('confirm').hidden === false`);
    assert.equal(await evaluate(`document.getElementById('delete').disabled`), true);
    await evaluate(`document.getElementById('cancel').click()`);
    await waitFor(`document.getElementById('status')?.textContent === 'Choose your account sign-in method.'`);
    assert.equal(deleteCalls, 0);
    assert.equal((await db.doc(`users/${uid}/saved/title`).get()).exists, true);
    await verify(password);
    await waitFor(`document.getElementById('confirm').hidden === false`);
    await evaluate(`document.getElementById('ack').checked=true;document.getElementById('ack').dispatchEvent(new Event('change'));document.getElementById('delete').click();`);
    await waitFor(`document.getElementById('status').textContent === 'Your account and server data have been deleted.'`);
    assert.equal(deleteCalls, 1);
    await assert.rejects(auth.getUser(uid), error => error.code === 'auth/user-not-found');
    assert.equal((await db.doc(`users/${uid}/saved/title`).get()).exists, false);
    const proof = { passed: true, browser: 'Chrome headless', projectId: process.env.FIREBASE_PROJECT_ID,
      wrongPasswordRejected: true, cancellationPreservedAccount: true, acknowledgementRequired: true,
      deletionCompleted: true, productionAccountsUsed: false, checkedAtUtc: new Date().toISOString() };
    fs.writeFileSync(path.join(__dirname, '../../reports/account-deletion-rollout/browser-integration.json'), JSON.stringify(proof, null, 2) + '\n');
  } finally {
    if (socket?.readyState === WebSocket.OPEN) {
      try { await call('Browser.close'); } catch (_) { /* Browser may close first. */ }
      socket.close();
    }
    if (browser.exitCode === null) browser.kill();
    for (const item of pending.values()) { clearTimeout(item.timeout); item.reject(Error('Browser closed')); }
    server.closeAllConnections(); server.close();
  }
}
module.exports = { browserDeletionCheck };
