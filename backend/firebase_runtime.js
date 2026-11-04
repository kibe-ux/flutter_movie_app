const { applicationDefault, cert, getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { initializeFirestore } = require('firebase-admin/firestore');

function runtimeOptions(env = process.env) {
  const projectId = env.FIREBASE_PROJECT_ID || env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) throw new Error('FIREBASE_PROJECT_ID is not configured.');
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return { projectId, credential: applicationDefault() };
  let key;
  try { key = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON); } catch (_) {
    throw new Error('Firebase runtime credentials are invalid.');
  }
  if (key.type !== 'service_account' || key.project_id !== projectId ||
      typeof key.private_key !== 'string' || typeof key.client_email !== 'string') {
    throw new Error('Firebase runtime credentials do not match this project.');
  }
  return { projectId, credential: cert(key) };
}

function getRuntimeFirebaseApp() {
  const name = 'moviehub-backend';
  const existing = getApps().find(app => app.name === name);
  if (existing) return existing;
  const app = initializeApp(runtimeOptions(), name);
  // HTTP transport also works in the hosted bundle and avoids gRPC native/DNS
  // requirements. The real-emulator integration test verifies bundled access.
  // The gRPC emulator transport uses its explicit owner identity. The HTTP
  // fallback can otherwise consult a developer's ADC even for localhost.
  initializeFirestore(app, { preferRest: !process.env.FIRESTORE_EMULATOR_HOST });
  return app;
}

function getRuntimeFirebaseAuth() { return getAuth(getRuntimeFirebaseApp()); }
module.exports = { getRuntimeFirebaseApp, getRuntimeFirebaseAuth, runtimeOptions };
