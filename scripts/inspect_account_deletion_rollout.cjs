// Read-only rollout checks. Saved CLI tokens stay in memory; reports contain
// configuration metadata only, never credentials or user account records.
const fs = require('node:fs');
const path = require('node:path');
process.env.DEBUG = '';
const root = path.resolve(__dirname, '..');
const project = 'my-flutter-app-hezra-202-12dc9';
const reportDir = path.join(root, 'reports/account-deletion-rollout');
async function main() {
  const auth = require('C:/nvm/nodejs/node_modules/firebase-tools/lib/auth.js');
  const account = auth.getProjectDefaultAccount(root);
  if (!account?.tokens?.refresh_token) throw Error('Firebase CLI sign-in is required.');
  const tokens = await auth.getAccessToken(account.tokens.refresh_token,
    ['https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/firebase']);
  async function get(url) {
    const r = await fetch(url, { headers: { Authorization: 'Bearer ' + tokens.access_token }, signal: AbortSignal.timeout(30000) });
    const data = await r.json();
    return { status: r.status, data };
  }
  const [config, google, apps, billing, serviceAccount] = await Promise.all([
    get(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`),
    get(`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/defaultSupportedIdpConfigs/google.com`),
    get(`https://firebase.googleapis.com/v1beta1/projects/${project}/webApps`),
    get(`https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`),
    get(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/moviehub-account-cleanup@${project}.iam.gserviceaccount.com`),
  ]);
  const report = { projectId: project, checkedAtUtc: new Date().toISOString(),
    authConfigStatus: config.status,
    authorizedDomains: config.status === 200 ? config.data.authorizedDomains : [],
    passwordSignInEnabled: config.status === 200 && config.data.signIn?.email?.enabled === true,
    googleSignInEnabled: google.status === 200 && google.data.enabled === true,
    webAppsStatus: apps.status, webApps: (apps.data.apps || []).map(app => ({ name: app.name, appId: app.appId, displayName: app.displayName })),
    billingStatus: billing.status, billingEnabled: billing.status === 200 ? billing.data.billingEnabled === true : null,
    cleanupServiceAccountExists: serviceAccount.status === 200,
  };
  fs.mkdirSync(reportDir, { recursive: true });
  fs.writeFileSync(path.join(reportDir, 'firebase-inspection.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report));
  if (config.status !== 200 || apps.status !== 200) process.exitCode = 1;
}
main().catch(() => { console.error('Rollout inspection failed; no cloud settings were modified.'); process.exitCode = 1; });
