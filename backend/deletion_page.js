// Public Firebase web identifiers, never service-account credentials.
const config = {
  apiKey: "AIzaSyDHjMPNmBGaDdkc00DwHZhiaagGNaKISP8",
  authDomain: 'my-flutter-app-hezra-202-12dc9.firebaseapp.com',
  projectId: 'my-flutter-app-hezra-202-12dc9',
  appId: '1:609797109604:web:a31f4ccb96e9c978f12c71',
};
const html = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Movie Hub — Delete account and data</title>
<style>body{font:17px/1.6 system-ui;max-width:650px;margin:48px auto;padding:0 24px;color:#242424}label,input,button{display:block;margin:12px 0}input,button{font:inherit;padding:10px;max-width:100%;box-sizing:border-box}button{cursor:pointer}#confirm{border:1px solid #a22;padding:16px}#status{white-space:pre-wrap}</style>
<main><h1>Delete your Movie Hub account</h1>
<p>You can request deletion here without installing the app. Sign in to verify that you own the account, then confirm deletion.</p>
<p>We delete your login and profile, forum posts and their replies (including replies from others), your replies on other posts, likes, reports you submitted or that target you, community-rules acceptance, block records, reward balances, ad-free passes, reward sessions and reward records. Your reviewer identity is removed from other reports you moderated. This cannot be undone.</p>
<p>Processing starts immediately. If interrupted, your request stays queued for retry. A record containing only your account ID and deletion status/times remains for up to seven days to prevent old sessions from recreating data.</p>
<p>Device-only lists and watch history on other devices cannot be remotely erased. Remove the app's data on those devices. Previously downloaded movie files remain under your control. Historical analytics, diagnostics and backups follow their providers' separate retention settings. For help or a request you cannot submit here, email <a href="mailto:privacymoviehub@gmail.com">privacymoviehub@gmail.com</a>. Never send your password.</p>
<section id="signin"><form id="email-form"><label>Email <input id="email" type="email" autocomplete="username" required></label>
<label>Password <input id="password" type="password" autocomplete="current-password" required></label><button>Verify with email and password</button></form>
<button id="google">Verify with Google</button><button id="reset">Send password reset email</button></section>
<section id="confirm" hidden><p id="identity"></p><label><input id="ack" type="checkbox"> I understand that my account and data will be permanently deleted.</label><button id="delete" disabled>Delete account and data</button><button id="cancel">Cancel and sign out</button></section>
<p id="status" role="status" aria-live="polite">Loading secure sign-in…</p>
<noscript>Enable JavaScript to verify your identity and submit a deletion request.</noscript></main>
<script type="module" src="./delete-account.js"></script></html>`;

const scriptTemplate = String.raw`
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import { getAuth, setPersistence, inMemoryPersistence, signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider, sendPasswordResetEmail, signOut, connectAuthEmulator } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';
const auth = getAuth(initializeApp(CONFIG));
EMULATOR_SETUP
const el = (id) => document.getElementById(id);
await setPersistence(auth, inMemoryPersistence);
el('status').textContent = 'Choose your account sign-in method.';
let busy = false;
async function verify(action) {
  if (busy) return;
  busy = true;
  try {
    await action();
    el('password').value = '';
    el('identity').textContent = 'Verified account: ' + (auth.currentUser.email || auth.currentUser.uid);
    el('signin').hidden = true;
    el('confirm').hidden = false;
    el('status').textContent = 'Review the deletion details and confirm below.';
  } catch (error) {
    const messages = {
      'auth/popup-blocked': 'Allow pop-ups for this page, then choose Verify with Google again.',
      'auth/popup-closed-by-user': 'Google sign-in was closed. Choose Verify with Google to try again.',
      'auth/unauthorized-domain': 'Google sign-in is not configured for this website yet. Please contact support.',
      'auth/network-request-failed': 'Could not connect to secure sign-in. Check your connection and try again.',
      'auth/cancelled-popup-request': 'Another sign-in window is open. Complete or close it before trying again.',
    };
    el('status').textContent = messages[error?.code] || 'Could not verify your account. Check your sign-in details and connection, then try again.';
  }
  finally { busy = false; }
}
el('email-form').addEventListener('submit', (e) => {
  e.preventDefault();
  verify(() => signInWithEmailAndPassword(auth, el('email').value.trim(), el('password').value));
});
el('google').addEventListener('click', () => verify(() => signInWithPopup(auth, new GoogleAuthProvider())));
el('reset').addEventListener('click', async () => {
  if (!el('email').reportValidity() || !el('email').value.trim()) return;
  try {
    await sendPasswordResetEmail(auth, el('email').value.trim());
    el('status').textContent = 'If eligible, a password reset email will arrive shortly.';
  } catch (_) { el('status').textContent = 'Could not request a reset. Please try again later.'; }
});
el('ack').addEventListener('change', () => { el('delete').disabled = !el('ack').checked; });
el('cancel').addEventListener('click', async () => { await signOut(auth); location.reload(); });
el('delete').addEventListener('click', async () => {
  if (busy || !el('ack').checked || !auth.currentUser) return;
  busy = true;
  el('delete').disabled = true;
  el('cancel').disabled = true;
  el('status').textContent = 'Submitting deletion. Please keep this page open.';
  try {
    const token = await auth.currentUser.getIdToken(true);
    const response = await fetch('./api/account', { method: 'DELETE', headers: { Authorization: 'Bearer ' + token } });
    if (!response.ok) throw new Error('Request failed');
    const result = await response.json();
    if (!((response.status === 200 && result.status === 'complete') || (response.status === 202 && result.status === 'pending'))) throw new Error('Unexpected response');
    el('confirm').hidden = true;
    el('status').textContent = result.status === 'complete' ? 'Your account and server data have been deleted.' : 'Your deletion request is saved and queued for retry. You do not need to submit it again.';
    await signOut(auth);
  } catch (_) {
    el('status').textContent = 'We could not confirm completion. Retry, or reload and verify your identity again. A request already received by the server will continue processing.';
    el('delete').disabled = false;
    el('cancel').disabled = false;
  } finally { busy = false; }
});
`;

function createDeletionPage({ firebaseConfig = config, authEmulatorUrl } = {}) {
  if (authEmulatorUrl && (!firebaseConfig.projectId.startsWith('demo-') ||
      authEmulatorUrl !== 'http://127.0.0.1:9098')) throw new Error('Only the isolated demo Auth emulator is allowed.');
  const script = scriptTemplate.replace('CONFIG', JSON.stringify(firebaseConfig)).replace('EMULATOR_SETUP',
    authEmulatorUrl ? `connectAuthEmulator(auth, ${JSON.stringify(authEmulatorUrl)}, { disableWarnings: true });` : '');
  return { html, script };
}
module.exports = { ...createDeletionPage(), createDeletionPage, config };
