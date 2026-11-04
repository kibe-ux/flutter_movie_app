const { createHash } = require('node:crypto');
const { createCatalogueStore } = require('./catalogue_store');

class WambeshaLimitError extends Error {
  constructor(status, message, retryAfter) {
    super(message); this.status = status; this.retryAfter = retryAfter;
  }
}

function setting(name, fallback, maximum) {
  const value = Number(process.env[name]);
  return Number.isInteger(value) && value > 0 && value <= maximum ? value : fallback;
}

// Reuse the atomic PostgreSQL rate buckets and their bounded cleanup. Keys use
// a separate namespace; neither identity nor signed delivery URLs are stored.
function createWambeshaLimits({ database, store = createCatalogueStore(database),
  now = Date.now, clientLimit = setting('WAMBESHA_CLIENT_LIMIT', 60, 1000),
  sourceLimit = setting('WAMBESHA_SOURCE_LIMIT', 8, 60),
  upstreamLimit = setting('WAMBESHA_UPSTREAM_LIMIT', 120, 1800),
} = {}) {
  let maintenanceAt = -Infinity;
  async function consume(key, limit, global = false) {
    try {
      const time = now();
      const retryAfter = await store.consume(`wambesha:${key}`, time, limit);
      if (retryAfter) throw new WambeshaLimitError(global ? 503 : 429,
        global ? 'Movie service is busy. Please try again later.'
          : 'Movie request limit reached. Please try again later.', retryAfter);
      if (time - maintenanceAt >= 60000) {
        maintenanceAt = time;
        // Cleanup failure never permits a request past a failed quota check.
        await store.cleanup(time);
      }
    } catch (error) {
      if (error instanceof WambeshaLimitError) throw error;
      throw new WambeshaLimitError(503, 'Movie service is temporarily unavailable.', 15);
    }
  }
  const identity = uid => createHash('sha256').update(uid).digest('hex');
  return {
    client: uid => consume(`client:${identity(uid)}`, clientLimit),
    source: uid => consume(`source:${identity(uid)}`, sourceLimit),
    upstream: () => consume('upstream', upstreamLimit, true),
  };
}

module.exports = { createWambeshaLimits, WambeshaLimitError };
