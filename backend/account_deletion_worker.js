const { getFirestore } = require('firebase-admin/firestore');
const { getRuntimeFirebaseAuth } = require('./firebase_runtime');
const { createAccountDeletion } = require('./account_deletion');

function createDeletionWorker({ auth = getRuntimeFirebaseAuth,
  service = (identity) => createAccountDeletion({ db: getFirestore(identity.app), auth: identity }),
  enabled = () => process.env.ACCOUNT_DELETION_WORKER_ENABLED === 'true',
  onNeon = () => !!process.env.NEON_BRANCH,
  log = (data) => console.log(JSON.stringify(data)) } = {}) {
  return {
    async fetch(request) {
      if (request.method !== 'POST' || new URL(request.url).pathname !== '/') {
        return new Response(null, { status: 404 });
      }
      // Neon strips client-provided X-Neon-* headers at its edge. Trust this
      // attestation only in the Neon runtime; never expose this via another host.
      // https://neon.com/docs/compute/functions/triggers/overview
      const id = request.headers.get('x-neon-trigger-invocation-id');
      if (!onNeon() || !id || id.length > 256) return new Response(null, { status: 403 });
      if (!enabled()) return Response.json({ error: 'Worker disabled' }, { status: 503 });
      let event;
      try {
        const body = await request.text();
        if (body.length > 8192) return new Response(null, { status: 413 });
        event = JSON.parse(body);
        if (event.invocation_id !== id || !Number.isFinite(Date.parse(event.data?.scheduled_at))) {
          return new Response(null, { status: 400 });
        }
      } catch (_) { return new Response(null, { status: 400 }); }
      try {
        const summary = await service(auth()).retryPending();
        log({ event: 'account-deletion-retry', ok: true, ...summary,
          ...(summary?.oldestPendingAgeMs > 3600000 ? { severity: 'ERROR', alert: 'pending-over-one-hour' } : {}) });
        return Response.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } });
      } catch (_) {
        log({ event: 'account-deletion-retry', ok: false, severity: 'ERROR' });
        return Response.json({ error: 'Retry pass failed' }, {
          status: 503, headers: { 'Retry-After': '300', 'Cache-Control': 'no-store' },
        });
      }
    },
  };
}
module.exports = { createDeletionWorker };
