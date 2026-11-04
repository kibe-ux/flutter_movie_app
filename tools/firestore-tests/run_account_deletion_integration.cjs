const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const { spawn } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const project = 'demo-moviehub-deletion';
let firestore;
let authServer;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function listening(port) {
  return new Promise(resolve => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(true); });
    socket.once('error', () => resolve(false));
  });
}
async function main() {
  if (await listening(8085) || await listening(9098)) throw Error('Emulator port in use; refusing to attach to an unknown server.');
  const jar = path.join(__dirname, '.emulator/cloud-firestore-emulator-v1.22.0.jar');
  if (crypto.createHash('sha256').update(fs.readFileSync(jar)).digest('hex') !== '9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c') throw Error('Emulator checksum mismatch.');
  process.env.DEBUG = '';
  const { createApp } = require('C:/nvm/nodejs/node_modules/firebase-tools/lib/emulator/auth/server.js');
  const app = await createApp(project);
  authServer = app.listen(9098, '127.0.0.1');
  await new Promise(resolve => authServer.once('listening', resolve));
  const java = path.join(process.env.ACCOUNT_TEST_JAVA_HOME || 'C:/Program Files/Android/Android Studio/jbr', 'bin/java.exe');
  const output = fs.createWriteStream(path.join(__dirname, '.emulator/account-deletion-firestore.log'));
  {
    firestore = spawn(java, ['-Xmx384m', '-XX:ActiveProcessorCount=2', '-jar', jar,
      '--host', '127.0.0.1', '--port', '8085', '--project_id', project, '--single_project_mode', 'true',
      '--rules', path.join(root, 'firestore.rules')], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    for (const stream of [firestore.stdout, firestore.stderr]) {
      let pending = '';
      stream.on('data', data => {
        pending += data.toString();
        const lines = pending.split('\n'); pending = lines.pop();
        for (const line of lines) output.write(line.replace(/ya29\.[A-Za-z0-9._~-]+/g, '[REDACTED]') + '\n');
      });
    }
    firestore.once('exit', () => output.end());
  }
  let spawnError;
  firestore.on('error', error => { spawnError = error; });
  let ready = false;
  for (let n = 0; n < 90; n++) {
    if (spawnError) throw spawnError;
    if (firestore.exitCode !== null) throw Error('Firestore emulator exited.');
    if (await listening(8085)) { ready = true; break; }
    await delay(500);
  }
  if (!ready) throw Error('Firestore emulator startup timed out.');
  const env = { ...process.env, FIREBASE_PROJECT_ID: project, GOOGLE_CLOUD_PROJECT: project, GCLOUD_PROJECT: project,
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8085', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9098',
    ACCOUNT_DELETION_ENABLED: 'true', ACCOUNT_DELETION_WORKER_ENABLED: 'true', NEON_BRANCH: 'local-emulator-test',
    FIREBASE_SERVICE_ACCOUNT_JSON: '', GOOGLE_APPLICATION_CREDENTIALS: '', NODE_ENV: 'test',
    APPDATA: path.join(__dirname, '.emulator/empty-appdata'),
    CLOUDSDK_CONFIG: path.join(__dirname, '.emulator/empty-gcloud'), GCE_METADATA_HOST: '127.0.0.1:9' };
  console.log('Testing deletion against real local Auth and Firestore emulators; no production accounts are used.');
  process.exitCode = await new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ['--test', path.join(__dirname, 'account_deletion.integration.cjs')], {
      env, cwd: root, windowsHide: true, stdio: 'inherit',
    });
    child.once('error', reject);
    child.once('exit', code => resolve(code ?? 1));
  });
}
main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => {
  if (firestore && firestore.exitCode === null) firestore.kill();
  if (authServer) { authServer.closeAllConnections(); authServer.close(); }
});
