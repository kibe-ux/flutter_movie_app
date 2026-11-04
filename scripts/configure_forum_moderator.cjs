// Assign only the explicitly selected, verified app account. Existing custom
// claims are preserved. Never prints Firebase account/session tokens.
const fs = require('node:fs');
const path = require('node:path');
process.env.DEBUG = '';
const root = path.resolve(__dirname, '..');
const projectId = 'my-flutter-app-hezra-202-12dc9';
const email = 'ngetichezra609@gmail.com';
async function main() {
  if (!process.argv[3]) throw new Error('Pass --check or --grant, then the firebase-tools directory.');
  const auth = require(path.join(process.argv[3], 'lib/auth.js'));
  const account = auth.getProjectDefaultAccount(root);
  if (!account?.tokens?.refresh_token) throw new Error('Sign in to Firebase CLI first.');
  const tokens = await auth.getAccessToken(account.tokens.refresh_token,
    ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']);
  async function request(action, body) {
    const response = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:${action}`, {
      method: 'POST', headers: { Authorization: 'Bearer ' + tokens.access_token, 'Content-Type': 'application/json' },
      body: JSON.stringify(body), signal: AbortSignal.timeout(30000),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(`Firebase Auth HTTP ${response.status}: ${data.error?.message || 'request failed'}`);
    return data;
  }
  const lookup = await request('lookup', { email: [email] });
  const users = (lookup.users || []).filter((user) => user.email?.toLowerCase() === email);
  if (users.length !== 1) throw new Error('The selected email has no unique app account. Sign in to Movie Hub with that email first.');
  const user = users[0];
  if (!user.emailVerified || user.disabled) throw new Error('The app account must have a verified email and be enabled before moderator access is granted.');
  const claims = JSON.parse(user.customAttributes || '{}');
  console.log(JSON.stringify({ email, uid: user.localId, emailVerified: true, moderator: claims.moderator === true }));
  if (process.argv[2] !== '--grant') { console.log('Read-only account check completed.'); return; }
  await request('update', { localId: user.localId, customAttributes: JSON.stringify({ ...claims, moderator: true }) });
  const verified = (await request('lookup', { localId: [user.localId] })).users?.[0];
  if (JSON.parse(verified?.customAttributes || '{}').moderator !== true) throw new Error('Moderator claim verification failed.');
  fs.writeFileSync(path.join(root, 'reports/firestore-security-2026-10-31/moderator-configuration.json'),
    JSON.stringify({ projectId, email, uid: user.localId, moderator: true, verifiedAtUtc: new Date().toISOString() }, null, 2) + '\n');
  console.log('Moderator claim saved and verified. Refresh app sign-in to receive it.');
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
