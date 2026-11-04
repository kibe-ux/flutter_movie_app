// Runs only as a local child process. Never imported by the production bundle.
const express = require('express');
const { performance, monitorEventLoopDelay } = require('node:perf_hooks');
const { setTimeout: delay } = require('node:timers/promises');
const { createCatalogue, registerCatalogueRoutes } = require('../catalogue');
const { registerWambeshaRoutes } = require('../wambesha');
const { createWambeshaLimits } = require('../wambesha_limits');
const { memoryStore, neonStore } = require('./store');

if (process.env.MOVIEHUB_LOAD_FIXTURE !== '1' || !process.send) throw new Error('Local load harness only');
const config = JSON.parse(process.env.MOVIEHUB_LOAD_CONFIG);
const stats = { providerCalls: { tmdb: 0, wambesha: 0 }, cache: {}, quotaRejected: {}, providerPeak: 0 };
let active = 0, server, resource, stopping = false;
let disconnected = false;
process.on('disconnect', () => { disconnected = true; if (server) void stop(); });
let cpuStart, start, rssPeak, heapPeak, sampler;
const loop = monitorEventLoopDelay({ resolution: 10 });
// Count the real route's structured cache events without benchmarking terminal IO.
console.log = line => {
  try { const event = JSON.parse(line); if (event.cache) stats.cache[event.cache] = (stats.cache[event.cache] || 0) + 1; }
  catch (_) { /* No fixture payloads or credentials are written to stdout. */ }
};
const authenticate = (req, res, next) => {
  const match = /^Bearer load-user-(\d+)$/.exec(req.header('authorization') || '');
  if (!match) return res.status(401).json({ error: 'Synthetic load identity required.' });
  req.firebaseUser = { uid: `load-user-${match[1]}` }; next();
};
async function provider(kind, url) {
  stats.providerCalls[kind]++; active++; stats.providerPeak = Math.max(active, stats.providerPeak);
  try {
    await delay(config.providerLatencyMs);
    if (kind === 'wambesha') {
      if (url.pathname.endsWith('/sources')) return Response.json({ sources: [
        { kind: 'file_holding', url: 'https://load-fixture.invalid/file.mp4', expires_at: new Date(Date.now() + 3600000).toISOString() },
      ] });
      return Response.json({ titles: { items: [{ id: 'mv_Load', type: 'movie' }] }, items: [] });
    }
    const detail = /^\/3\/movie\/(\d+)$/.exec(url.pathname);
    if (detail) return Response.json({ id: Number(detail[1]), overview: 'Synthetic metadata. '.repeat(500) });
    return Response.json({ page: 1, results: Array.from({ length: 20 }, (_, i) => ({
      id: i + 1, title: `Fixture movie ${i}`, overview: 'Synthetic metadata. '.repeat(35), poster_path: '/fixture.jpg',
    })), total_pages: 10 });
  } finally { active--; }
}
async function stop() {
  if (stopping) return; stopping = true;
  clearInterval(sampler); loop.disable();
  if (server) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
  let cleaned = true;
  try { await resource?.cleanup?.(); } catch (_) { cleaned = false; }
  if (process.connected) process.send({ type: 'stopped', cleaned, schema: resource?.schema });
  process.exitCode = cleaned ? 0 : 1;
  if (process.connected) process.disconnect();
}
function snapshot() {
  const cpu = process.cpuUsage(cpuStart);
  return { ...stats, storeCalls: { ...resource.calls }, elapsedMs: performance.now() - start,
    cpuMs: (cpu.user + cpu.system) / 1000,
    rssPeakBytes: rssPeak, heapPeakBytes: heapPeak, rssEndBytes: process.memoryUsage().rss,
    eventLoopP95Ms: loop.percentile(95) / 1e6, eventLoopMaxMs: loop.max / 1e6 };
}
async function main() {
  resource = config.store === 'neon' ? await neonStore() : (() => {
    const store = memoryStore(config.storeLatencyMs); return { store, calls: store.calls };
  })();
  if (disconnected) return stop();
  const app = express();
  const capacity = config.profile === 'capacity';
  const catalogue = createCatalogue({ store: resource.store,
    keyProvider: () => 'synthetic-key-not-a-provider-credential',
    fetchImpl: url => provider('tmdb', url),
    userLimit: capacity ? 1000000 : 120, upstreamLimit: capacity ? 1000000 : 600,
  });
  registerCatalogueRoutes(app, { authenticate, service: catalogue });
  const limits = createWambeshaLimits({ store: resource.store,
    clientLimit: capacity ? 1000000 : 60, sourceLimit: capacity ? 1000000 : 8,
    upstreamLimit: capacity ? 1000000 : 120 });
  const measured = Object.fromEntries(Object.entries(limits).map(([name, action]) => [name, async (...args) => {
    try { return await action(...args); }
    catch (error) { stats.quotaRejected[name] = (stats.quotaRejected[name] || 0) + 1; throw error; }
  }]));
  process.env.WAMBESHA_API_KEY = 'synthetic-key-not-a-provider-credential';
  registerWambeshaRoutes(app, { authenticate, limits: measured, fetchImpl: url => provider('wambesha', url) });
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  process.on('message', message => {
    if (message.type === 'begin') {
      stats.providerCalls = { tmdb: 0, wambesha: 0 }; stats.cache = {}; stats.quotaRejected = {};
      stats.providerPeak = 0; resource.calls && Object.keys(resource.calls).forEach(key => { resource.calls[key] = 0; });
      start = performance.now(); cpuStart = process.cpuUsage(); loop.enable(); loop.reset();
      rssPeak = process.memoryUsage().rss; heapPeak = process.memoryUsage().heapUsed;
      sampler = setInterval(() => { const mem = process.memoryUsage(); rssPeak = Math.max(rssPeak, mem.rss); heapPeak = Math.max(heapPeak, mem.heapUsed); }, 100);
      sampler.unref(); process.send({ type: 'begun' });
    }
    if (message.type === 'stats') process.send({ type: 'stats', value: snapshot() });
    if (message.type === 'stop') void stop();
  });
  process.send({ type: 'ready', port: server.address().port, schema: resource.schema });
}
main().catch(() => { process.send?.({ type: 'failure', error: 'Local fixture initialization failed' }); void stop(); });
