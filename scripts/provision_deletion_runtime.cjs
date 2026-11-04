// Create a dedicated cleanup identity and add only the actual deletion-page
// host to Firebase Auth. Does not change billing, issue a key or delete data.
const fs = require('node:fs');
const path = require('node:path');
process.env.DEBUG = '';
const root = path.resolve(__dirname, '..');
const project = 'my-flutter-app-hezra-202-12dc9';
const accountId = 'moviehub-account-cleanup';
const email = `${accountId}@${project}.iam.gserviceaccount.com`;
const roleId = 'movieHubAccountCleanup';
const roleName = `projects/${project}/roles/${roleId}`;
const deletionHost = 'br-empty-forest-b4htkwt9-moviehub.compute.c-6.us-east-2.aws.neon.tech';
const permissions = ['datastore.databases.get', 'datastore.entities.get', 'datastore.entities.list',
  'datastore.entities.create', 'datastore.entities.update', 'datastore.entities.delete',
  'firebaseauth.users.get', 'firebaseauth.users.delete'];
async function googleRequest() {
  const auth = require('C:/nvm/nodejs/node_modules/firebase-tools/lib/auth.js');
  const account = auth.getProjectDefaultAccount(root);
  if (!account?.tokens?.refresh_token) throw Error('Firebase CLI sign-in is required.');
  const tokens = await auth.getAccessToken(account.tokens.refresh_token,
    ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']);
  return async (url, method = 'GET', body) => {
    const response = await fetch(url, { method, headers: { Authorization: 'Bearer ' + tokens.access_token,
      'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(45000) });
    const data = response.status === 204 ? {} : await response.json();
    if (!response.ok && response.status !== 404) {
      const error = Error(`Google API HTTP ${response.status}: ${data.error?.status || 'request failed'}`);
      error.reasons = (data.error?.details || []).map(d=>d.reason).filter(r=>typeof r==='string'&&/^[A-Z_]+$/.test(r));
      error.detailMessage = data.error?.message;
      throw error;
    }
    return { status: response.status, data };
  };
}
async function configure() {
  const request = await googleRequest();
  const saUrl = `https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/${email}`;
  let sa = await request(saUrl);
  if (sa.status === 404) sa = await request(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts`, 'POST', {
    accountId, serviceAccount: { displayName: 'Movie Hub account cleanup', description: 'Dedicated runtime for authenticated account cleanup and scheduled retries.' },
  });
  if (sa.data.email !== email || sa.data.disabled) throw Error('Unexpected or disabled runtime identity.');
  const roleUrl = 'https://iam.googleapis.com/v1/' + roleName;
  let role = await request(roleUrl);
  if (role.status === 404) role = await request(`https://iam.googleapis.com/v1/projects/${project}/roles`, 'POST', {
    roleId, role: { title: 'Movie Hub account cleanup', description: 'Only Firestore record operations and Auth user lookup/deletion.',
      stage: 'GA', includedPermissions: permissions },
  });
  if (role.data.deleted || JSON.stringify([...role.data.includedPermissions].sort()) !== JSON.stringify([...permissions].sort())) {
    throw Error('Existing custom role differs from the reviewed minimum permissions.');
  }
  const policyUrl = `https://cloudresourcemanager.googleapis.com/v1/projects/${project}`;
  const policy = (await request(policyUrl + ':getIamPolicy', 'POST', { options: { requestedPolicyVersion: 3 } })).data;
  const member = 'serviceAccount:' + email;
  if (!(policy.bindings || []).some(binding => binding.role === roleName && !binding.condition && binding.members.includes(member))) {
    policy.bindings ||= [];
    policy.bindings.push({ role: roleName, members: [member] });
    await request(policyUrl + ':setIamPolicy', 'POST', { policy });
  }
  const configUrl = `https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`;
  const config = (await request(configUrl)).data;
  if (!config.authorizedDomains?.includes(deletionHost)) {
    await request(configUrl + '?updateMask=authorizedDomains', 'PATCH', {
      authorizedDomains: [...(config.authorizedDomains || []), deletionHost],
    });
  }
  const proof = { projectId: project, runtimeServiceAccount: email, roleName, permissions,
    authorizedDeletionHost: deletionHost, billingChanged: false, keysCreated: false, configuredAtUtc: new Date().toISOString() };
  const dir = path.join(root, 'reports/account-deletion-rollout'); fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'runtime-identity.json'), JSON.stringify(proof, null, 2) + '\n');
  console.log(JSON.stringify(proof));
}
if (require.main === module) {
  if (process.argv[2] !== '--configure') {
    console.log(JSON.stringify({ planOnly: true, projectId: project, runtimeServiceAccount: email, roleName, permissions,
      authorizedDeletionHost: deletionHost, billingChanged: false, keysCreated: false }));
  } else configure().catch(error => { console.error(error.message); process.exitCode = 1; });
}
module.exports = { googleRequest, configure, project, email, permissions, root };
