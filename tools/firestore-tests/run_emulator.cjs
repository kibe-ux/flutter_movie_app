const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const { spawn } = require('node:child_process');

const cache = path.join(__dirname, '.emulator');
const jar = path.join(cache, 'cloud-firestore-emulator-v1.22.0.jar');
const java = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'java.exe' : 'java') : 'java';
const port = 8085;
let emulator;
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
function listening() {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host: '127.0.0.1', port });
    socket.once('connect', () => { socket.destroy(); resolve(true); });
    socket.once('error', () => { socket.destroy(); resolve(false); });
    socket.setTimeout(500, () => { socket.destroy(); resolve(false); });
  });
}
async function main() {
  if (await listening()) throw new Error('Port 8085 is in use. Refusing to attach tests to an unknown server.');
  if (!fs.existsSync(jar)) throw new Error('Download the official Firestore emulator 1.22.0 jar into tools/firestore-tests/.emulator first.');
  const digest = crypto.createHash('sha256').update(fs.readFileSync(jar)).digest('hex');
  if (digest !== '9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c') throw new Error('Emulator checksum does not match the Firebase CLI release metadata.');
  const output = fs.openSync(path.join(cache, 'firestore-output.log'), 'w');
  try {
    emulator = spawn(java, ['-jar', jar, '--host', '127.0.0.1', '--port', String(port),
      '--project_id', 'demo-moviehub-security', '--single_project_mode', 'true',
      '--rules', path.resolve(__dirname, '../../firestore.rules')], {
      windowsHide: true, stdio: ['ignore', output, output], cwd: __dirname,
    });
  } finally { fs.closeSync(output); }
  let startupError;
  emulator.on('error', (error) => { startupError = error; });
  let ready = false;
  for (let attempt = 0; attempt < 90; attempt++) {
    if (startupError) throw startupError;
    if (emulator.exitCode !== null) throw new Error('Emulator exited. See tools/firestore-tests/.emulator/firestore-output.log.');
    if (await listening()) { ready = true; break; }
    await delay(500);
  }
  if (!ready) throw new Error('Emulator did not become ready within 45 seconds.');
  console.log('Running security tests against the local demo project only.');
  const rulesPath = path.resolve(__dirname, '../../firestore.rules');
  const rulesSha256 = crypto.createHash('sha256').update(fs.readFileSync(rulesPath)).digest('hex');
  const status = await new Promise((resolve, reject) => {
    const tests = spawn(process.execPath, ['--test', path.join(__dirname, 'forum_rules.test.cjs')], {
      windowsHide: true, stdio: 'inherit', cwd: __dirname,
      env: { ...process.env, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8085', GCLOUD_PROJECT: 'demo-moviehub-security', GOOGLE_CLOUD_PROJECT: 'demo-moviehub-security' },
    });
    tests.on('error', reject);
    tests.on('exit', (code) => resolve(code ?? 1));
  });
  process.exitCode = status;
  if (status === 0) {
    if (crypto.createHash('sha256').update(fs.readFileSync(rulesPath)).digest('hex') !== rulesSha256) {
      throw new Error('Rule source changed while tests ran; repeat validation.');
    }
    const directory = path.resolve(__dirname, '../../reports/firestore-security-2026-10-31');
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(directory, 'forum-rules-tests.json'), JSON.stringify({
      passed: true, emulatorVersion: '1.22.0', projectId: 'demo-moviehub-security',
      transport: 'REST against the real local Firestore emulator', rulesSha256,
      testsSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(__dirname, 'forum_rules.test.cjs'))).digest('hex'),
      checkedAtUtc: new Date().toISOString(),
    }, null, 2) + '\n');
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; })
  .finally(() => { if (emulator && emulator.exitCode === null) emulator.kill(); });
