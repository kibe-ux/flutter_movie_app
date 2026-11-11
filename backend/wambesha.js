const { createHash } = require('node:crypto');
const { createCatalogueStore } = require('./catalogue_store');
const { createSharedSourceCache } = require('./wambesha_shared_cache');
const { createWambeshaBudget } = require('./wambesha_budget');
const { metadataTtl, createWambeshaMetadataCache } = require('./wambesha_metadata_cache');
const express = require('express');
const { createWambeshaLimits, WambeshaLimitError } = require('./wambesha_limits');
const { readProviderJson, withAbort, cancelBody, createSourceCache,
  MAX_PROVIDER_TASKS, PROVIDER_TIMEOUT_MS, EXPIRY_MARGIN_MS } = require('./wambesha_resources');

// Keep external references bounded and confined to one URL path segment.
const TITLE_REF_PATTERN = '(?:(?:mv|sr|sn|ep)_[A-Za-z0-9]{1,40}|imdb:tt[0-9]{1,20}|tvdb:[0-9]{1,20}|tmdb:(?:movie|tv):[0-9]{1,20})';
const TITLE_REF = new RegExp(`^${TITLE_REF_PATTERN}(?![\\s\\S])`);
const TITLE_PATH = new RegExp(`^/titles/(${TITLE_REF_PATTERN})(?:/(sources|episodes))?(?![\\s\\S])`);

class WambeshaRequestError extends Error {
  constructor(status, message, retryAfter = 0) {
    super(message); this.status = status; this.retryAfter = retryAfter;
  }
}

function sendRequestError(res, error) {
  const controlled = error instanceof WambeshaRequestError || error instanceof WambeshaLimitError;
  if (controlled && error.retryAfter) res.set('Retry-After', String(error.retryAfter));
  const timeout = error?.name === 'TimeoutError';
  return res.status(controlled ? error.status : timeout ? 504 : 502).json({
    error: controlled ? error.message : timeout
      ? 'Movie catalogue request timed out.' : 'Movie catalogue is unavailable.',
  });
}

function registerWambeshaRoutes(app, { authenticate, database,
  limits = createWambeshaLimits({ database }), fetchImpl = (...args) => fetch(...args),
  now = Date.now, providerTimeoutMs = PROVIDER_TIMEOUT_MS,
  sharedSources = process.env.WAMBESHA_SHARED_SOURCES === 'true',
  persistentSources = process.env.WAMBESHA_PERSISTENT_SOURCES !== 'false',
  sourceStore, budget = createWambeshaBudget({ database, now }),
  metadataCache = createWambeshaMetadataCache({ store: createCatalogueStore(database), now }),
  onUsage = event => console.log(JSON.stringify(event)) } = {}) {
  if (!Number.isInteger(providerTimeoutMs) || providerTimeoutMs < 1 || providerTimeoutMs > PROVIDER_TIMEOUT_MS) {
    throw new RangeError('Invalid provider deadline.');
  }
  const router = express.Router();
  router.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });
  router.use(authenticate);

  // In-flight request coalescing and per-user cache
  const inFlightSources = new Map();
  const sourcesCache = createSourceCache({ now });
  let activeProviderTasks = 0;
  let pendingSourceTasks = 0;
  const sharedCache = (sharedSources || persistentSources) ? createSharedSourceCache({
    store: sourceStore || createCatalogueStore(database), now }) : null;
  async function usage(event, fields = {}) {
    // Never include user IDs, title IDs, signed URLs, credentials or response bodies.
    try { onUsage({ component: 'wambesha-usage', event, ...fields }); } catch (_) {}
    try { await budget.record(event, fields); }
    catch (_) { try { onUsage({ component: 'wambesha-usage', event: 'reporting-error' }); } catch (_) {} }
  }

  function getUserId(req) {
    return req.firebaseUser?.uid;
  }

  function sanitizeSources(body) {
    // Normalize the current provider envelope for existing app clients.
    const links = body.links !== undefined ? body.links : body.sources;
    if (!Array.isArray(links)) throw new Error('Invalid source response.');
    const time = now();
    const sanitized = {
      id: typeof body.id === 'string' ? body.id : undefined,
      checked_at: typeof body.checked_at === 'string' ? body.checked_at : undefined,
      unverified: Number.isSafeInteger(body.unverified) && body.unverified >= 0 ? body.unverified : 0,
      sources: [],
      subtitles: [],
      trailers: [],
    };
    function validLink(item, requireExpiry = false) {
      if (!item || typeof item !== 'object' || typeof item.url !== 'string') return false;
      try {
        const parsed = new URL(item.url);
        if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.username || parsed.password) return false;
      } catch (_) { return false; }
      if (item.expires_at == null) return !requireExpiry;
      return typeof item.expires_at === 'string' &&
        Date.parse(item.expires_at) > time + EXPIRY_MARGIN_MS;
    }
    function metadata(from, to) {
      for (const field of ['quality', 'locale', 'language']) {
        if (typeof from[field] === 'string' && from[field].length <= 80) to[field] = from[field];
      }
      if (Number.isSafeInteger(from.bytes) && from.bytes >= 0) to.bytes = from.bytes;
      return to;
    }
    if (Array.isArray(links)) {
      for (const source of links) {
        if (!source || typeof source !== 'object') continue;
        const kind = source.kind;
        if (kind !== 'file_holding' && kind !== 'playback_holding') continue;
        const url = source.url;
        if (typeof url !== 'string') continue;
        let parsed;
        try { parsed = new URL(url); } catch (_) { continue; }
        if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.username || parsed.password) continue;
        if (source.expires_at !== undefined && source.expires_at !== null) {
          const expiresAt = typeof source.expires_at === 'string' ? Date.parse(source.expires_at) : NaN;
          if (!Number.isFinite(expiresAt) || expiresAt <= time + EXPIRY_MARGIN_MS) continue;
        }
        const item = { kind, url };
        if (source.expires_at) item.expires_at = source.expires_at;
        if (typeof source.host === 'string') item.host = source.host;
        if (typeof source.verified_at === 'string') item.verified_at = source.verified_at;
        if (typeof source.quality === 'string' && source.quality.length <= 80) item.quality = source.quality;
        sanitized.sources.push(metadata(source, item));
      }
    }
    for (const field of ['subtitles', 'trailers']) {
      if (body[field] !== undefined && !Array.isArray(body[field])) throw new Error('Invalid source metadata.');
    }
    for (const item of body.subtitles || []) {
      if (!validLink(item, true) || item.format !== 'vtt' ||
          typeof item.language !== 'string' || !item.language || item.language.length > 80) continue;
      sanitized.subtitles.push({ url: item.url, expires_at: item.expires_at,
        language: item.language, format: item.format });
    }
    for (const item of body.trailers || []) {
      if (!item || !['direct', 'youtube'].includes(item.hosted) ||
          !validLink(item, item.hosted === 'direct')) continue;
      if (item.hosted === 'youtube' &&
          !['youtube.com', 'www.youtube.com', 'm.youtube.com', 'youtu.be'].includes(new URL(item.url).hostname)) continue;
      const trailer = metadata(item, { hosted: item.hosted, url: item.url });
      if (item.expires_at != null) trailer.expires_at = item.expires_at;
      sanitized.trailers.push(trailer);
    }
    if (typeof body.verification_spent === 'boolean') sanitized.verification_spent = body.verification_spent;
    return sanitized;
  }

  router.use(async (req, res) => {
    if (req.method !== 'GET') {
      return res.set('Allow', 'GET').status(405).json({ error: 'Method not allowed.' });
    }

    const key = process.env.WAMBESHA_API_KEY?.trim();
    if (!key) {
      return res.status(503).json({ error: 'Movie search is not configured.' });
    }

    const url = new URL('https://api.wambesha.com');
    const allowed = new Set(['language']);
    let isSourcesEndpoint = false;
    let titleRef = '';

    let providerPath;
    try { providerPath = decodeURIComponent(req.path); }
    catch (_) { return res.status(400).json({ error: 'Invalid catalogue path.' }); }
    const titleMatch = providerPath.match(TITLE_PATH);
    const sourcesMatch = titleMatch?.[2] === 'sources' ? titleMatch : null;
    const episodesMatch = titleMatch?.[2] === 'episodes' ? titleMatch : null;
    const singleTitleMatch = titleMatch && !titleMatch[2] ? titleMatch : null;

    if (req.path === '/search') {
      allowed.add('q');
      if (typeof req.query.q !== 'string' || req.query.q.trim().length < 2 || req.query.q.length > 200) {
        return res.status(400).json({ error: 'Enter between 2 and 200 characters.' });
      }
    } else if (req.path === '/titles') {
      allowed.add('ids');
      const ids = typeof req.query.ids === 'string' ? req.query.ids.split(',') : [];
      if (!ids.length || ids.length > 100 || ids.some(id => !TITLE_REF.test(id))) {
        return res.status(400).json({ error: 'Supply up to 100 valid title references.' });
      }
    } else if (req.path === '/lookup') {
      allowed.add('tmdb_id');
      allowed.add('imdb_id');
      allowed.add('type');
      const hasTmdb = typeof req.query.tmdb_id === 'string' && /^\d+$/.test(req.query.tmdb_id);
      const hasImdb = typeof req.query.imdb_id === 'string' && /^tt\d+$/.test(req.query.imdb_id);
      if ((hasTmdb && hasImdb) || (!hasTmdb && !hasImdb)) {
        return res.status(400).json({ error: 'Provide either a valid tmdb_id or imdb_id.' });
      }
      if (req.query.type !== undefined && (!hasTmdb ||
          !['movie', 'tv_movie', 'short', 'special', 'series', 'mini_series', 'season', 'episode'].includes(req.query.type))) {
        return res.status(400).json({ error: 'Supply a valid type with tmdb_id.' });
      }
    } else if (episodesMatch) {
      allowed.add('season');
      allowed.add('limit');
      allowed.add('cursor');
      if (req.query.limit !== undefined) {
        const limitNum = Number(req.query.limit);
        if (Number.isNaN(limitNum) || limitNum < 1 || limitNum > 50) {
          return res.status(400).json({ error: 'Limit must be between 1 and 50.' });
        }
      }
    } else if (req.path === '/discover') {
      allowed.add('type');
      allowed.add('genre');
      allowed.add('year');
      allowed.add('cursor');
      allowed.add('limit');
    } else if (req.path === '/recommendations') {
      allowed.add('id');
      allowed.add('limit');
    } else if (sourcesMatch) {
      isSourcesEndpoint = true;
      titleRef = sourcesMatch[1];
    } else if (req.path !== '/genres' && !singleTitleMatch) {
      return res.status(404).json({ error: 'Unknown catalogue endpoint.' });
    }

    if (Object.entries(req.query).some(([name, value]) => !allowed.has(name) || typeof value !== 'string')) {
      return res.status(400).json({ error: 'Unsupported catalogue parameters.' });
    }

    const userId = getUserId(req);
    if (typeof userId !== 'string' || !userId) {
      return res.status(401).json({ error: 'A verified Firebase user is required.' });
    }
    try { await limits.client(userId); }
    catch (error) { return sendRequestError(res, error); }
    const language = req.query.language || 'default';
    const credentialScope = createHash('sha256').update(key).digest('hex');
    const sourceScope = `${sharedSources ? 'shared' : userId}:${titleRef}:${language}:${credentialScope}`;
    const sharedKey = `wambesha-source:v1:${createHash('sha256').update(sourceScope).digest('hex')}`;

    if (isSourcesEndpoint) {
      const cached = sourcesCache.get(sourceScope);
      if (cached) {
        await usage('cache-hit');
        res.set('X-MovieHub-Source-Cache', 'HIT');
        res.set('X-MovieHub-Response-Source', 'wambesha');
        return res.type('application/json').send(cached);
      }

      // In-flight coalescing for simultaneous taps
      const pendingSource = inFlightSources.get(sourceScope);
      if (pendingSource) {
        await usage('coalesced');
        res.set('X-MovieHub-Source-Cache', 'COALESCED');
        try {
          const sharedData = await pendingSource;
          res.set('X-MovieHub-Response-Source', 'wambesha');
          return res.json(sharedData);
        } catch (sharedError) {
          return sendRequestError(res, sharedError);
        }
      }
    }

    // Admission precedes async quota/fetch work, bounding both active bodies
    // and the per-process source-promise map. Followers reuse an existing slot.
    if (activeProviderTasks >= MAX_PROVIDER_TASKS || pendingSourceTasks >= MAX_PROVIDER_TASKS) {
      return sendRequestError(res, new WambeshaRequestError(503,
        'Movie service is busy. Please try again later.', 1));
    }

    url.pathname = `/v1${providerPath}`;
    url.search = new URLSearchParams(req.query).toString();
    res.set('X-MovieHub-Response-Source', 'wambesha');

    const executeFetch = async () => {
      activeProviderTasks++;
      const controller = new AbortController();
      let timer;
      try {
        if (isSourcesEndpoint) await limits.source(userId);
        await limits.upstream();
        try { await budget.reserve(isSourcesEndpoint); }
        catch (error) { await usage('quota-rejected'); throw error; }
        timer = setTimeout(() => controller.abort(
          new DOMException('Provider deadline exceeded.', 'TimeoutError')), providerTimeoutMs);
        timer.unref();
        await usage('upstream-request', { sources: isSourcesEndpoint });
        const upstream = await withAbort(fetchImpl(url, {
          headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
          redirect: 'error',
          signal: controller.signal,
        }), controller.signal);

        await usage('upstream-response', { sources: isSourcesEndpoint, status: upstream.status });
        const retryAfter = upstream.headers.get('retry-after');
        if (retryAfter && /^\d+$/.test(retryAfter)) res.set('Retry-After', retryAfter);

        if (!upstream.ok) {
          cancelBody(upstream.body);
          const status = [401, 403].includes(upstream.status) ? 502 : upstream.status;
          throw new WambeshaRequestError(status, upstream.status === 429
            ? 'Movie search limit reached. Please try again later.'
            : 'Movie catalogue is unavailable.');
        }

        const rawJson = await readProviderJson(upstream, controller.signal);
        if (isSourcesEndpoint) {
          const spent = rawJson.verification_spent;
          await usage('verification', { spent: spent === true || spent === 1 ? 1
            : spent === false || spent === 0 ? 0 : null });
          return sanitizeSources(rawJson);
        }
        const ttl = metadataTtl(providerPath);
        if (ttl) {
          const single = providerPath === '/lookup' || /^\/titles\/[^/]+$/.test(providerPath);
          if (single ? typeof rawJson.id !== 'string' : !Array.isArray(rawJson.items)) {
            throw new Error('Invalid metadata response.');
          }
        }
        return rawJson;
      } finally {
        clearTimeout(timer);
        controller.abort();
        activeProviderTasks--;
      }
    };

    if (isSourcesEndpoint) {
      pendingSourceTasks++;
      const fetchPromise = sharedCache
        ? sharedCache.get(sharedKey, executeFetch).then(async result => {
            await usage('shared-cache', { cache: result.cache });
            res.set('X-MovieHub-Source-Cache', result.cache);
            return result.body;
          })
        : executeFetch();
      inFlightSources.set(sourceScope, fetchPromise);
      try {
        const data = await fetchPromise;
        sourcesCache.set(sourceScope, data);
        return res.json(data);
      } catch (err) {
        await usage('source-error');
        return sendRequestError(res, err);
      } finally {
        pendingSourceTasks--;
        inFlightSources.delete(sourceScope);
      }
    }

    try {
      const ttl = metadataTtl(providerPath);
      let data;
      if (metadataCache && ttl) {
        const params = new URLSearchParams(req.query);
        params.sort();
        const metadataKey = `wambesha-metadata:v1:${createHash('sha256')
          .update(`${credentialScope}:${providerPath}?${params}`).digest('hex')}`;
        const result = await metadataCache.get(metadataKey, ttl, executeFetch);
        if (result.hit) await usage('metadata-cache-hit');
        res.set('X-MovieHub-Metadata-Cache', result.hit ? 'HIT' : 'MISS');
        data = result.body;
      } else {
        data = await executeFetch();
      }
      return res.json(data);
    } catch (error) {
      return sendRequestError(res, error);
    }
  });

  app.use('/api/wambesha', router);
}

module.exports = { registerWambeshaRoutes };
