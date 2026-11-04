// REST transport for actual Firestore emulator rule tests. No SDK doubles and
// no Google credentials: mock identities are accepted only by the local emulator.
const assert = require('node:assert/strict');
const projectId = 'demo-moviehub-security';
const origin = 'http://127.0.0.1:8085';
const database = `projects/${projectId}/databases/(default)`;
const documents = `${database}/documents`;
function guard() {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8085');
  assert.equal(process.env.GOOGLE_CLOUD_PROJECT, projectId);
}
class RestError extends Error {
  constructor(status, code, message) { super(`${code}: ${message}`); this.status = status; this.code = code; }
}
function token(uid, claims) {
  const now = Math.floor(Date.now() / 1000);
  const payload = { aud: projectId, iss: `https://securetoken.google.com/${projectId}`,
    sub: uid, user_id: uid, auth_time: now, iat: now, exp: now + 3600,
    firebase: { sign_in_provider: 'password' }, ...claims };
  return Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url') + '.' +
    Buffer.from(JSON.stringify(payload)).toString('base64url') + '.';
}
async function request(db, resource, method = 'GET', body, missingAllowed = false) {
  guard();
  const response = await fetch(origin + resource, { method,
    headers: { 'Content-Type': 'application/json', ...(db.token ? { Authorization: 'Bearer ' + db.token } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(20000) });
  const data = await response.json();
  if (missingAllowed && response.status === 404) return null;
  if (!response.ok) throw new RestError(response.status, data.error?.status, data.error?.message);
  return data;
}
function encode(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  if (value?.timestamp) return { timestampValue: value.timestamp };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, encode(entry)])) } };
}
function decode(value) {
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decode);
  return Object.fromEntries(Object.entries(value.mapValue?.fields || {}).map(([key, entry]) => [key, decode(entry)]));
}
const doc = (db, location) => ({ db, location, name: `${documents}/${location}` });
const collection = (db, location) => ({ db, location });
const serverTimestamp = () => ({ transform: 'timestamp' });
const increment = (value) => ({ transform: 'increment', value });
const Timestamp = { fromMillis: (value) => ({ timestamp: new Date(value).toISOString() }) };
function write(ref, data, patch = false) {
  const fields = {};
  const transforms = [];
  for (const [fieldPath, value] of Object.entries(data)) {
    if (value?.transform === 'timestamp') transforms.push({ fieldPath, setToServerValue: 'REQUEST_TIME' });
    else if (value?.transform === 'increment') transforms.push({ fieldPath, increment: encode(value.value) });
    else fields[fieldPath] = encode(value);
  }
  return { update: { name: ref.name, fields },
    ...(patch ? { currentDocument: { exists: true }, updateMask: { fieldPaths: Object.keys(fields) } } : {}),
    ...(transforms.length ? { updateTransforms: transforms } : {}) };
}
function commit(db, writes) { return request(db, '/v1/' + database + '/documents:commit', 'POST', { writes }); }
const setDoc = (ref, data) => commit(ref.db, [write(ref, data)]);
const updateDoc = (ref, data) => commit(ref.db, [write(ref, data, true)]);
const deleteDoc = (ref) => commit(ref.db, [{ delete: ref.name }]);
function writeBatch(db) {
  const writes = [];
  return { set: (ref, data) => { writes.push(write(ref, data)); },
    update: (ref, data) => { writes.push(write(ref, data, true)); },
    delete: (ref) => { writes.push({ delete: ref.name }); }, commit: () => commit(db, writes) };
}
async function getDoc(ref) {
  const data = await request(ref.db, '/v1/' + ref.name, 'GET', undefined, true);
  return { exists: () => data !== null,
    data: () => data ? Object.fromEntries(Object.entries(data.fields || {}).map(([key, value]) => [key, decode(value)])) : undefined };
}
const where = (field, op, value) => ({ kind: 'where', field, op, value });
const orderBy = (field, direction) => ({ kind: 'order', field, direction });
const query = (ref, ...clauses) => ({ ...ref, clauses });
async function getDocs(ref) {
  const structuredQuery = { from: [{ collectionId: ref.location }] };
  for (const clause of ref.clauses || []) {
    if (clause.kind === 'where') {
      assert.equal(clause.op, '==');
      structuredQuery.where = { fieldFilter: { field: { fieldPath: clause.field }, op: 'EQUAL', value: encode(clause.value) } };
    } else structuredQuery.orderBy = [{ field: { fieldPath: clause.field }, direction: clause.direction === 'desc' ? 'DESCENDING' : 'ASCENDING' }];
  }
  return request(ref.db, '/v1/' + documents + ':runQuery', 'POST', { structuredQuery });
}
async function initializeTestEnvironment(options) {
  guard();
  assert.equal(options.projectId, projectId);
  const admin = { token: 'owner' }; // Special local-emulator credential, never sent to Google.
  return {
    authenticatedContext: (uid, claims) => ({ firestore: () => ({ token: token(uid, claims) }) }),
    unauthenticatedContext: () => ({ firestore: () => ({}) }),
    withSecurityRulesDisabled: (callback) => callback({ firestore: () => admin }),
    clearFirestore: () => request(admin, '/emulator/v1/' + documents, 'DELETE'),
    cleanup: async () => {},
  };
}
async function assertFails(promise) {
  await assert.rejects(promise, (error) => error instanceof RestError && error.status === 403 && error.code === 'PERMISSION_DENIED');
}
module.exports = { initializeTestEnvironment, assertFails, assertSucceeds: (promise) => promise,
  doc, collection, getDoc, getDocs, query, where, orderBy, setDoc, updateDoc, deleteDoc,
  writeBatch, serverTimestamp, Timestamp, increment, setLogLevel: () => {} };
