const express = require('express');
const { createWambeshaLimits, WambeshaLimitError } = require('./wambesha_limits');
const { readProviderJson, withAbort, cancelBody, createSourceCache,
  MAX_PROVIDER_TASKS, PROVIDER_TIMEOUT_MS, EXPIRY_MARGIN_MS } = require('./wambesha_resources');

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
  now = Date.now, providerTimeoutMs = PROVIDER_TIMEOUT_MS } = {}) {
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

  function getUserId(req) {
    return req.firebaseUser?.uid;
  }

  function sanitizeSources(body) {
    if (!Array.isArray(body.sources)) throw new Error('Invalid source response.');
    const time = now();
    const sanitized = {
      id: typeof body.id === 'string' ? body.id : undefined,
      checked_at: typeof body.checked_at === 'string' ? body.checked_at : undefined,
      unverified: Number.isSafeInteger(body.unverified) && body.unverified >= 0 ? body.unverified : 0,
      sources: [],
    };
    if (Array.isArray(body.sources)) {
      for (const source of body.sources) {
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
        sanitized.sources.push(item);
      }
    }
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

    const sourcesMatch = req.path.match(/^\/titles\/((?:mv|sr|ep)_[A-Za-z0-9]{1,40})\/sources$/);
    const episodesMatch = req.path.match(/^\/titles\/(sr_[A-Za-z0-9]{1,40})\/episodes$/);
    const singleTitleMatch = req.path.match(/^\/titles\/((?:mv|sr)_[A-Za-z0-9]{1,40})$/);

    if (req.path === '/search') {
      allowed.add('q');
      if (typeof req.query.q !== 'string' || req.query.q.trim().length < 2 || req.query.q.length > 200) {
        return res.status(400).json({ error: 'Enter between 2 and 200 characters.' });
      }
    } else if (req.path === '/titles') {
      allowed.add('ids');
      const ids = typeof req.query.ids === 'string' ? req.query.ids.split(',') : [];
      if (!ids.length || ids.length > 100 || ids.some(id => !/^(mv|sr)_[A-Za-z0-9]{1,40}$/.test(id))) {
        return res.status(400).json({ error: 'Supply up to 100 movie or series IDs.' });
      }
    } else if (req.path === '/lookup') {
      allowed.add('tmdb_id');
      allowed.add('imdb_id');
      const hasTmdb = typeof req.query.tmdb_id === 'string' && /^\d+$/.test(req.query.tmdb_id);
      const hasImdb = typeof req.query.imdb_id === 'string' && /^tt\d+$/.test(req.query.imdb_id);
      if ((hasTmdb && hasImdb) || (!hasTmdb && !hasImdb)) {
        return res.status(400).json({ error: 'Provide either a valid tmdb_id or imdb_id.' });
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
    const sourceScope = `${userId}:${titleRef}`;

    if (isSourcesEndpoint) {
      const cached = sourcesCache.get(sourceScope);
      if (cached) {
        res.set('X-MovieHub-Response-Source', 'wambesha');
        return res.type('application/json').send(cached);
      }

      // In-flight coalescing for simultaneous taps
      if (inFlightSources.has(sourceScope)) {
        try {
          const sharedData = await inFlightSources.get(sourceScope);
          res.set('X-MovieHub-Response-Source', 'wambesha');
          return res.json(sharedData);
        } catch (sharedError) {
          return sendRequestError(res, sharedError);
        }
      }
    }

    // Admission precedes async quota/fetch work, bounding both active bodies
    // and the per-process source-promise map. Followers reuse an existing slot.
    if (activeProviderTasks >= MAX_PROVIDER_TASKS) {
      return sendRequestError(res, new WambeshaRequestError(503,
        'Movie service is busy. Please try again later.', 1));
    }

    url.pathname = `/v1${req.path}`;
    url.search = new URLSearchParams(req.query).toString();
    res.set('X-MovieHub-Response-Source', 'wambesha');

    const executeFetch = async () => {
      activeProviderTasks++;
      const controller = new AbortController();
      let timer;
      try {
        if (isSourcesEndpoint) await limits.source(userId);
        await limits.upstream();
        timer = setTimeout(() => controller.abort(
          new DOMException('Provider deadline exceeded.', 'TimeoutError')), providerTimeoutMs);
        timer.unref();
        const upstream = await withAbort(fetchImpl(url, {
          headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
          redirect: 'error',
          signal: controller.signal,
        }), controller.signal);

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
          return sanitizeSources(rawJson);
        }
        return rawJson;
      } finally {
        clearTimeout(timer);
        controller.abort();
        activeProviderTasks--;
      }
    };

    if (isSourcesEndpoint) {
      const fetchPromise = executeFetch();
      inFlightSources.set(sourceScope, fetchPromise);
      try {
        const data = await fetchPromise;
        sourcesCache.set(sourceScope, data);
        return res.json(data);
      } catch (err) {
        return sendRequestError(res, err);
      } finally {
        inFlightSources.delete(sourceScope);
      }
    }

    try {
      const data = await executeFetch();
      return res.json(data);
    } catch (error) {
      return sendRequestError(res, error);
    }
  });

  app.use('/api/wambesha', router);
}

module.exports = { registerWambeshaRoutes };
