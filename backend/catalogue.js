const express = require('express');
const { createHash, randomUUID } = require('node:crypto');
const { setTimeout: delay } = require('node:timers/promises');
const { createCatalogueStore } = require('./catalogue_store');

class CatalogueError extends Error {
  constructor(status, message, retryAfter = 0) {
    super(message); this.status = status; this.retryAfter = retryAfter;
  }
}
const unavailable = () => new CatalogueError(503, 'Movie information is temporarily unavailable.', 15);
const digest = text => createHash('sha256').update(text).digest('hex');
const boundedSetting = (name, fallback, max) => {
  const n = Number(process.env[name]);
  return Number.isInteger(n) && n > 0 && n <= max ? n : fallback;
};

// A fixed host, finite routes and validated parameters prevent an open proxy
// and avoid using random query parameters to defeat the shared cache.
function catalogueRequest(path, query) {
  const lists = /^\/(?:movie\/(?:popular|now_playing|top_rated|upcoming)|tv\/(?:popular|top_rated|airing_today|on_the_air)|trending\/(?:movie|tv)\/(?:day|week)|discover\/(?:movie|tv)|search\/(?:movie|tv)|genre\/(?:movie|tv)\/list)$/;
  const details = /^\/(?:movie|tv)\/[1-9]\d{0,9}(?:\/(?:credits|videos|similar|recommendations|watch\/providers|release_dates|content_ratings|external_ids))?$/;
  const seasons = /^\/tv\/[1-9]\d{0,9}\/season\/(?:0|[1-9]\d{0,2})$/;
  if (!lists.test(path) && !details.test(path) && !seasons.test(path)) {
    throw new CatalogueError(404, 'Unknown movie information endpoint.');
  }
  const rules = {
    language: /^[a-z]{2}(?:-[A-Z]{2})?$/,
    page: /^(?:[1-9]|[1-9]\d|[1-4]\d\d|500)$/,
    with_genres: /^\d{1,5}(?:[,|]\d{1,5}){0,4}$/,
    sort_by: /^(?:popularity|vote_average|vote_count|release_date|primary_release_date|first_air_date|revenue)\.(?:asc|desc)$/,
    'release_date.lte': /^\d{4}-\d{2}-\d{2}$/,
    'vote_count.gte': /^\d{1,5}$/,
    append_to_response: /^(?:credits|videos|watch\/providers|release_dates|content_ratings|external_ids)(?:,(?:credits|videos|watch\/providers|release_dates|content_ratings|external_ids)){0,5}$/,
  };
  const params = new URLSearchParams();
  for (const [name, value] of Object.entries(query)) {
    if (typeof value !== 'string' || value.length > 200) throw new CatalogueError(400, 'Invalid catalogue parameters.');
    if (name === 'query' && path.startsWith('/search/') && value.trim().length >= 2) {
      params.set(name, value.trim().replace(/\s+/g, ' '));
    } else if (Object.hasOwn(rules, name) && rules[name].test(value)) {
      const isDetail = details.test(path) || seasons.test(path);
      if ((name === 'append_to_response' && (!isDetail || path.split('/').length !== 3)) ||
          (['with_genres', 'sort_by', 'release_date.lte', 'vote_count.gte'].includes(name) && !path.startsWith('/discover/')) ||
          (name === 'page' && (!lists.test(path) || path.startsWith('/genre/')))) {
        throw new CatalogueError(400, 'Unsupported catalogue parameters.');
      }
      params.set(name, name === 'append_to_response' ? [...new Set(value.split(','))].sort().join(',') : value);
    } else throw new CatalogueError(400, 'Unsupported catalogue parameters.');
  }
  if (path.startsWith('/search/') && !params.has('query')) throw new CatalogueError(400, 'A search query is required.');
  if (!params.has('language')) params.set('language', 'en-US');
  if (lists.test(path) && !path.startsWith('/genre/') && !params.has('page')) params.set('page', '1');
  params.sort();
  return { path, params, key: digest(`${path}?${params}`) };
}

async function readJson(response) {
  const reader = response.body?.getReader();
  if (!reader) throw unavailable();
  const chunks = []; let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 1024 * 1024) { await reader.cancel(); throw unavailable(); }
      chunks.push(Buffer.from(value));
    }
    const data = JSON.parse(Buffer.concat(chunks, size).toString('utf8'));
    if (!data || typeof data !== 'object' || Array.isArray(data) || data.success === false) throw unavailable();
    return data;
  } finally { reader.releaseLock(); }
}

function createCatalogue({ store, fetchImpl = fetch, now = Date.now,
  sleep = delay, keyProvider = () => process.env.TMDB_API_KEY?.trim(),
  ttlMs = 15 * 60000, staleMs = 60 * 60000,
  userLimit = 120, upstreamLimit = 600, waitMs = 20000,
} = {}) {
  const local = new Map(); const pending = new Map();
  let localBytes = 0;
  let cleaningAt = 0;
  function remember(key, entry) {
    const bytes = Buffer.byteLength(JSON.stringify(entry.body));
    localBytes -= local.get(key)?.bytes || 0;
    local.delete(key);
    while (local.size && (local.size >= 128 || localBytes + bytes > 16 * 1024 * 1024)) {
      const oldest = local.keys().next().value;
      localBytes -= local.get(oldest).bytes;
      local.delete(oldest);
    }
    local.set(key, { ...entry, bytes });
    localBytes += bytes;
  }
  function result(entry, cache) { return { body: entry.body, cache }; }
  async function load(request) {
    const { key } = request;
    const memory = local.get(key);
    if (memory?.fresh_until > now()) return result(memory, 'HIT');
    let saved;
    try { saved = await store.read(key); }
    catch { if (memory?.stale_until > now()) return result(memory, 'STALE'); throw unavailable(); }
    if (saved?.body && saved.fresh_until > now()) {
      remember(key, saved); return result(saved, 'HIT');
    }
    const stale = saved?.body && saved.stale_until > now() ? saved : memory?.stale_until > now() ? memory : null;
    if (saved?.retry_at > now()) {
      if (stale) return result(stale, 'STALE');
      throw unavailable();
    }
    const owner = randomUUID();
    if (!await store.acquire(key, owner, now(), 60000)) {
      if (stale) return result(stale, 'STALE');
      const deadline = now() + waitMs;
      while (now() < deadline) {
        await sleep(250);
        const entry = await store.read(key);
        if (entry?.body && entry.fresh_until > now()) { remember(key, entry); return result(entry, 'COALESCED'); }
        if (entry?.retry_at > now() || entry?.lease_until <= now()) break;
      }
      throw unavailable();
    }
    try {
      const retry = await store.consume('tmdb:upstream', now(), upstreamLimit);
      if (retry) {
        console.log(JSON.stringify({ endpoint: '/api/catalogue', event: 'upstream-budget-rejected' }));
        throw new CatalogueError(503, 'Movie information is busy. Please try again shortly.', retry);
      }
      const url = new URL(`https://api.themoviedb.org/3${request.path}`);
      url.search = request.params.toString();
      url.searchParams.set('api_key', keyProvider());
      console.log(JSON.stringify({ endpoint: '/api/catalogue', event: 'upstream-request' }));
      const response = await fetchImpl(url, { signal: AbortSignal.timeout(15000), redirect: 'error' });
      if (!response.ok) throw unavailable();
      const body = await readJson(response);
      // Reject incomplete successful responses instead of caching provider errors.
      const isList = /\/(?:popular|now_playing|top_rated|upcoming|airing_today|on_the_air|similar|recommendations|videos)$/.test(request.path) ||
        /^\/(?:discover|search|trending)\//.test(request.path);
      if ((request.path.startsWith('/genre/') && !Array.isArray(body.genres)) ||
          (isList && !Array.isArray(body.results)) ||
          (/^\/(?:movie|tv)\/\d+$/.test(request.path) && body.id !== Number(request.path.split('/')[2])) ||
          (/\/season\/\d+$/.test(request.path) && !Array.isArray(body.episodes))) throw unavailable();
      const entry = { body, fresh_until: now() + ttlMs, stale_until: now() + ttlMs + staleMs };
      await store.publish(key, owner, body, entry.fresh_until, entry.stale_until);
      remember(key, entry);
      return result(entry, 'MISS');
    } catch (error) {
      await store.release(key, owner, now() + 15000).catch(() => {});
      if (stale) return result(stale, 'STALE');
      throw error instanceof CatalogueError ? error : unavailable();
    }
  }
  return {
    async get(request, identity) {
      if (!keyProvider()) throw new CatalogueError(503, 'Movie information is not configured.');
      // Never accept a UID from a header; the route supplies verified auth or
      // a guest installation ID. A global provider budget also covers guests
      // who reset their installation ID.
      let retry;
      try { retry = await store.consume(`client:${digest(identity)}`, now(), userLimit); }
      catch { throw unavailable(); }
      if (retry) throw new CatalogueError(429, 'Too many requests. Please try again shortly.', retry);
      if (now() >= cleaningAt) {
        cleaningAt = now() + 60000;
        // Maintenance failure must not expose database details to clients.
        await store.cleanup(now()).catch(() => {});
      }
      if (pending.has(request.key)) {
        const value = await pending.get(request.key);
        return { ...value, cache: value.cache === 'STALE' ? 'STALE' : 'COALESCED' };
      }
      const task = load(request);
      pending.set(request.key, task);
      try { return await task; } finally { pending.delete(request.key); }
    },
  };
}

function registerCatalogueRoutes(app, { authenticate, database, service } = {}) {
  const catalogue = service || createCatalogue({
    store: createCatalogueStore(database),
    userLimit: boundedSetting('CATALOGUE_CLIENT_LIMIT', 120, 1000),
    upstreamLimit: boundedSetting('CATALOGUE_UPSTREAM_LIMIT', 600, 1800),
  });
  const router = express.Router();
  router.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    if (req.header('authorization')) return authenticate(req, res, next);
    return next();
  });
  router.use(async (req, res) => {
    try {
      if (req.method !== 'GET') return res.set('Allow', 'GET').status(405).json({ error: 'Method not allowed.' });
      const request = catalogueRequest(req.path, req.query);
      const installation = req.header('x-moviehub-installation') || '';
      const identity = req.firebaseUser?.uid ? `user:${req.firebaseUser.uid}`
        : /^[a-f0-9]{32}$/.test(installation) ? `guest:${installation}` : null;
      if (!identity) throw new CatalogueError(400, 'A valid app installation ID is required.');
      const value = await catalogue.get(request, identity);
      res.set('X-MovieHub-Cache', value.cache);
      if (value.cache === 'STALE') res.set('Warning', '110 - "Response is stale"');
      console.log(JSON.stringify({ endpoint: '/api/catalogue', cache: value.cache, status: 200 }));
      return res.json(value.body);
    } catch (error) {
      const safe = error instanceof CatalogueError ? error : unavailable();
      if (safe.retryAfter) res.set('Retry-After', String(safe.retryAfter));
      console.log(JSON.stringify({ endpoint: '/api/catalogue', status: safe.status }));
      return res.status(safe.status).json({ error: safe.message });
    }
  });
  app.use('/api/catalogue/3', router);
}

module.exports = { catalogueRequest, createCatalogue, registerCatalogueRoutes, CatalogueError };
