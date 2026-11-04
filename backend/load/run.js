const http = require('node:http');
const os = require('node:os');
const fs = require('node:fs');
const path = require('node:path');
const { fork, execFileSync } = require('node:child_process');
const { performance } = require('node:perf_hooks');
const { createHash } = require('node:crypto');

const scenarios = new Set(['catalogue-warm', 'catalogue-cold', 'source-warm', 'source-cold', 'search']);
const cataloguePaths = ['movie/popular', 'movie/now_playing', 'movie/top_rated', 'trending/movie/day'];
function options(argv) {
  const allowed = new Set(['scenario', 'rate', 'duration', 'users', 'concurrency', 'store', 'store-latency', 'provider-latency', 'profile']);
  const result = { scenario: 'catalogue-warm', rate: 100, duration: 10, users: 50000,
    concurrency: 256, store: 'memory', storeLatencyMs: 5, providerLatencyMs: 100, profile: 'production' };
  const numeric = { rate: [1, 2000], duration: [1, 60], users: [1, 50000], concurrency: [1, 512],
    'store-latency': [0, 250], 'provider-latency': [0, 1000] };
  for (const arg of argv) {
    const match = /^--([a-z-]+)=([^=]+)$/.exec(arg);
    if (!match || !allowed.has(match[1])) throw new Error('Use documented --name=value options; remote targets are not supported.');
    const [, key, value] = match;
    const name = key === 'store-latency' ? 'storeLatencyMs' : key === 'provider-latency' ? 'providerLatencyMs' : key;
    if (numeric[key]) {
      const number = Number(value), [minimum, maximum] = numeric[key];
      if (!Number.isInteger(number) || number < minimum || number > maximum) throw new Error(`Invalid ${key}`);
      result[name] = number;
    } else result[name] = value;
  }
  if (!scenarios.has(result.scenario) || !['memory', 'neon'].includes(result.store) ||
      !['production', 'capacity'].includes(result.profile)) throw new Error('Invalid load profile.');
  // Database runs are isolated and intentionally low volume. No public URL option.
  if (result.store === 'neon' && (result.rate > 20 || result.duration > 10 || result.concurrency > 20 || result.profile !== 'production')) {
    throw new Error('Neon probe maximum: 20 RPS, 10 seconds, 20 in flight, production limits.');
  }
  return result;
}
function percentile(values, fraction) {
  if (!values.length) return null;
  const sorted = values.slice().sort((a, b) => a - b);
  return Math.round(sorted[Math.ceil(sorted.length * fraction) - 1] * 100) / 100;
}
function request(port, agent, route, user, scheduledAt = performance.now()) {
  return new Promise(resolve => {
    const sentAt = performance.now();
    let finished = false, bytes = 0;
    function finish(value) {
      if (finished) return; finished = true;
      resolve({ ...value, bytes, latencyMs: performance.now() - sentAt,
        endToEndMs: performance.now() - scheduledAt, schedulerLagMs: sentAt - scheduledAt });
    }
    const req = http.get({ host: '127.0.0.1', port, path: route, agent, headers: {
      'X-MovieHub-Installation': user.toString(16).padStart(32, '0'),
      Authorization: `Bearer load-user-${user}`,
    } }, res => {
      res.on('data', chunk => { bytes += chunk.length; });
      res.on('end', () => finish({ status: res.statusCode, cache: res.headers['x-moviehub-cache'] }));
      res.on('error', () => finish({ error: 'response-error' }));
      res.on('aborted', () => finish({ error: 'response-aborted' }));
    });
    req.setTimeout(10000, () => { finish({ error: 'timeout' }); req.destroy(); });
    req.on('error', () => finish({ error: 'connection-error' }));
  });
}
function route(config, index) {
  if (config.scenario === 'catalogue-warm') return `/api/catalogue/3/${cataloguePaths[index % 4]}?page=1`;
  if (config.scenario === 'catalogue-cold') return `/api/catalogue/3/movie/${index + 1}`;
  if (config.scenario === 'search') return `/api/wambesha/search?q=Fixture${index}`;
  return '/api/wambesha/titles/mv_Load/sources';
}
async function arrivals(config, port, agent) {
  const total = config.rate * config.duration, pending = new Set(), results = [];
  const start = performance.now(); let index = 0, notSent = 0;
  const users = config.scenario === 'source-warm' ? Math.min(config.users, 80) : config.users;
  await new Promise(resolve => {
    function tick() {
      const now = performance.now();
      while (index < total && start + index * 1000 / config.rate <= now) {
        const job = index++, due = start + job * 1000 / config.rate;
        if (pending.size >= config.concurrency) { notSent++; continue; }
        const task = request(port, agent, route(config, job), job % users, due)
          .then(result => results.push(result)).finally(() => pending.delete(task));
        pending.add(task);
      }
      if (index === total) resolve();
      else setTimeout(tick, Math.max(1, start + index * 1000 / config.rate - performance.now()));
    }
    tick();
  });
  await Promise.all(pending);
  const elapsedMs = performance.now() - start;
  const successful = results.filter(result => result.status >= 200 && result.status < 300);
  const statuses = {}, errors = {};
  for (const result of results) {
    if (result.status) statuses[result.status] = (statuses[result.status] || 0) + 1;
    if (result.error) errors[result.error] = (errors[result.error] || 0) + 1;
  }
  const p95 = percentile(successful.map(result => result.endToEndMs), .95);
  return { scheduled: total, sent: results.length, generatorDropped: notSent, successful: successful.length,
    availabilityPercent: successful.length / total * 100, elapsedMs, statuses, errors,
    completedRps: results.length / (elapsedMs / 1000), successfulRps: successful.length / (elapsedMs / 1000),
    transferredBytes: results.reduce((sum, result) => sum + result.bytes, 0),
    successLatencyMs: { p50: percentile(successful.map(r => r.endToEndMs), .5), p95,
      p99: percentile(successful.map(r => r.endToEndMs), .99) },
    allResponsesP95Ms: percentile(results.map(r => r.endToEndMs), .95),
    schedulerLagP95Ms: percentile(results.map(r => r.schedulerLagMs), .95),
    slo: { definition: '99% of scheduled arrivals succeed, successful p95 <=250ms, zero generator drops/transport errors',
      passed: successful.length / total >= .99 && p95 !== null && p95 <= 250 && notSent === 0 && Object.keys(errors).length === 0 } };
}
async function run(config) {
  // Revalidate programmatic callers, including the database safety bounds.
  config = options(Object.entries(config).map(([key, value]) =>
    `--${key === 'storeLatencyMs' ? 'store-latency' : key === 'providerLatencyMs' ? 'provider-latency' : key}=${value}`));
  const startedAtUtc = new Date().toISOString();
  const root = path.resolve(__dirname, '../..');
  const child = fork(path.join(__dirname, 'fixture.js'), [], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
    env: { ...process.env, MOVIEHUB_LOAD_FIXTURE: '1', MOVIEHUB_LOAD_CONFIG: JSON.stringify(config) },
  });
  const queued = [], waiters = [];
  let childExited = false;
  child.on('message', value => { const waiter = waiters.shift(); waiter ? waiter(value) : queued.push(value); });
  child.on('exit', () => { childExited = true; while (waiters.length) waiters.shift()({ type: 'exit' }); });
  child.on('error', () => { childExited = true; while (waiters.length) waiters.shift()({ type: 'child-error' }); });
  function receive(type, timeoutMs = 60000) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const index = waiters.indexOf(callback); if (index >= 0) waiters.splice(index, 1);
        reject(new Error(`Timed out waiting for fixture ${type}`));
      }, timeoutMs);
      const callback = value => { clearTimeout(timer); value.type === type ? resolve(value) : reject(new Error('Unexpected fixture response: ' + value.type)); };
      if (childExited && !queued.length) return callback({ type: 'exit' });
      queued.length ? callback(queued.shift()) : waiters.push(callback);
    });
  }
  let agent, ready, report, cleanupSucceeded = false;
  try {
    ready = await receive('ready');
    agent = new http.Agent({ keepAlive: true, maxSockets: config.concurrency, maxFreeSockets: config.concurrency });
    const warmup = [];
    if (config.scenario === 'catalogue-warm') {
      for (let i = 0; i < 4; i++) warmup.push(await request(ready.port, agent, route(config, i), 0));
    }
    if (config.scenario === 'source-warm') {
      for (let index = 0; index < Math.min(config.users, 80); index += 4) {
        const users = Array.from({ length: Math.min(4, Math.min(config.users, 80) - index) }, (_, i) => index + i);
        warmup.push(...await Promise.all(users.map(user => request(ready.port, agent, route(config, 0), user))));
      }
    }
    if (warmup.some(result => result.status !== 200)) throw new Error('Warmup failed; no capacity result is valid.');
    child.send({ type: 'begin' }); await receive('begun');
    const load = await arrivals(config, ready.port, agent);
    child.send({ type: 'stats' }); const server = (await receive('stats')).value;
    report = { startedAtUtc, completedAtUtc: new Date().toISOString(), scope: 'loopback production routes; simulated identities/providers; separate server and generator processes',
      exclusions: ['Firebase token/App Check verification', 'Firestore rewards/forum', 'Neon hosting cold starts/scaling', 'provider network and availability', 'movie file transfer', 'production logging sink'],
      config, load, server, storeCleanupSucceeded: false,
      environment: { node: process.version, platform: process.platform, logicalCpus: os.availableParallelism(),
        cpuModel: os.cpus()[0]?.model, totalMemoryBytes: os.totalmem(),
        gitCommit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
        sourceHashes: Object.fromEntries(['catalogue.js', 'wambesha.js', 'wambesha_resources.js', 'wambesha_limits.js', 'catalogue_store.js']
          .map(file => [file, createHash('sha256').update(fs.readFileSync(path.join(root, 'backend', file))).digest('hex')])) },
    };
    report.server.cpuEquivalentCores = server.cpuMs / server.elapsedMs;
  } finally {
    agent?.destroy();
    if (child.connected) {
      child.send({ type: 'stop' });
    }
    if (child.connected || queued.some(message => message.type === 'stopped')) {
      const stopped = await receive('stopped', 45000); cleanupSucceeded = stopped.cleaned;
    }
    if (report) report.storeCleanupSucceeded = cleanupSucceeded;
    if (!cleanupSucceeded) throw new Error(`Fixture cleanup failed; inspect isolated load-test schema ${ready?.schema || '(initialization did not finish)'} before retrying.`);
  }
  const folder = path.join(root, 'reports/load-tests'); fs.mkdirSync(folder, { recursive: true });
  const filename = `${new Date().toISOString().replace(/[:.]/g, '-')}-${config.scenario}-${config.rate}rps-${config.store}.json`;
  fs.writeFileSync(path.join(folder, filename), JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ report: path.relative(root, path.join(folder, filename)),
    scenario: config.scenario, store: config.store, rate: config.rate, scheduled: report.load.scheduled,
    successfulRps: +report.load.successfulRps.toFixed(2), p95Ms: report.load.successLatencyMs.p95,
    availabilityPercent: +report.load.availabilityPercent.toFixed(2), statuses: report.load.statuses,
    transportErrors: report.load.errors,
    generatorDropped: report.load.generatorDropped, providerCalls: report.server.providerCalls,
    sloPassed: report.load.slo.passed, cleaned: report.storeCleanupSucceeded }));
  return report;
}
if (require.main === module) {
  let config;
  try { config = options(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 1; }
  if (config) run(config).catch(error => { console.error(error.message); process.exitCode = 1; });
}
module.exports = { options, percentile, run };
