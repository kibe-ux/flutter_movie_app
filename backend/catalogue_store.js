// Atomic PostgreSQL state shared by every API instance.
const MAX_CATALOGUE_BYTES = 100_000_000;

function createCatalogueStore(database, { maxBytes = MAX_CATALOGUE_BYTES } = {}) {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 1 || maxBytes > MAX_CATALOGUE_BYTES) {
    throw new RangeError('Catalogue storage budget must be between 1 and 100,000,000 bytes.');
  }
  let ready;
  async function ensure() {
    if (!ready) ready = (async () => {
      await database.query(`CREATE TABLE IF NOT EXISTS moviehub_catalogue_cache (
        cache_key text PRIMARY KEY, body jsonb, fresh_until bigint NOT NULL DEFAULT 0,
        stale_until bigint NOT NULL DEFAULT 0, lease_until bigint NOT NULL DEFAULT 0,
        lease_owner text, retry_at bigint NOT NULL DEFAULT 0,
        payload_bytes bigint NOT NULL DEFAULT 0)`);
      await database.query(`ALTER TABLE moviehub_catalogue_cache
        ADD COLUMN IF NOT EXISTS payload_bytes bigint NOT NULL DEFAULT 0`);
      await database.query(`UPDATE moviehub_catalogue_cache
        SET payload_bytes = octet_length(body::text)
        WHERE body IS NOT NULL AND payload_bytes = 0`);
      await database.query(`CREATE TABLE IF NOT EXISTS moviehub_catalogue_limits (
        bucket_key text PRIMARY KEY, window_start bigint NOT NULL, hits integer NOT NULL)`);
    })().catch(error => { ready = null; throw error; });
    await ready;
  }
  function budgetStatements(preferredKey = null) {
    return [{
      text: `SELECT pg_advisory_xact_lock($1, $2)`,
      parameters: [75481, 100],
    }, {
      // Keep recent pages, giving the just-published page first priority.
      // Clear payloads rather than deleting active lease rows, so another
      // instance's refresh cannot lose its lock or be duplicated.
      text: `WITH ranked AS (
        SELECT cache_key, sum(payload_bytes) OVER (
          ORDER BY (cache_key = $1::text) DESC NULLS LAST,
                   fresh_until DESC, cache_key ROWS UNBOUNDED PRECEDING) AS retained_bytes
        FROM moviehub_catalogue_cache WHERE body IS NOT NULL
      ) UPDATE moviehub_catalogue_cache SET body = NULL, payload_bytes = 0,
          fresh_until = 0, stale_until = 0
        WHERE cache_key IN (SELECT cache_key FROM ranked WHERE retained_bytes > $2)`,
      parameters: [preferredKey, maxBytes],
    }];
  }
  return {
    async read(key) {
      await ensure();
      return (await database.query(`SELECT body, fresh_until, stale_until, lease_until, retry_at
        FROM moviehub_catalogue_cache WHERE cache_key = $1`, [key]))[0];
    },
    async acquire(key, owner, now, leaseMs) {
      await ensure();
      const rows = await database.query(`INSERT INTO moviehub_catalogue_cache
        (cache_key, lease_owner, lease_until) VALUES ($1, $2, $3)
        ON CONFLICT (cache_key) DO UPDATE SET lease_owner = $2, lease_until = $3
        WHERE moviehub_catalogue_cache.lease_until <= $4
          AND moviehub_catalogue_cache.fresh_until <= $4
          AND moviehub_catalogue_cache.retry_at <= $4
        RETURNING cache_key`, [key, owner, now + leaseMs, now]);
      return rows.length > 0;
    },
    async publish(key, owner, body, freshUntil, staleUntil) {
      await ensure();
      const [lock, evict] = budgetStatements(key);
      await database.transaction([lock, {
        text: `WITH incoming AS (SELECT $3::jsonb AS body,
          octet_length(($3::jsonb)::text)::bigint AS bytes)
        UPDATE moviehub_catalogue_cache AS cached SET
          body = CASE WHEN incoming.bytes <= $6 THEN incoming.body ELSE cached.body END,
          payload_bytes = CASE WHEN incoming.bytes <= $6 THEN incoming.bytes ELSE cached.payload_bytes END,
          fresh_until = CASE WHEN incoming.bytes <= $6 THEN $4 ELSE cached.fresh_until END,
          stale_until = CASE WHEN incoming.bytes <= $6 THEN $5 ELSE cached.stale_until END,
          lease_until = 0, lease_owner = NULL, retry_at = 0
        FROM incoming WHERE cache_key = $1 AND lease_owner = $2`,
        parameters: [key, owner, JSON.stringify(body), freshUntil, staleUntil, maxBytes],
      }, evict]);
    },
    async release(key, owner, retryAt) {
      await database.query(`UPDATE moviehub_catalogue_cache SET lease_until = 0,
        lease_owner = NULL, retry_at = $3 WHERE cache_key = $1 AND lease_owner = $2`,
      [key, owner, retryAt]);
    },
    async consume(key, now, limit, windowMs = 60000) {
      await ensure();
      const start = Math.floor(now / windowMs) * windowMs;
      const rows = await database.query(`INSERT INTO moviehub_catalogue_limits
        (bucket_key, window_start, hits) VALUES ($1, $2, 1)
        ON CONFLICT (bucket_key) DO UPDATE SET window_start = $2,
          hits = CASE WHEN moviehub_catalogue_limits.window_start <> $2 THEN 1
                      ELSE moviehub_catalogue_limits.hits + 1 END
        WHERE moviehub_catalogue_limits.window_start <> $2 OR moviehub_catalogue_limits.hits < $3
        RETURNING hits`, [key, start, limit]);
      return rows.length ? 0 : Math.max(1, Math.ceil((start + windowMs - now) / 1000));
    },
    async cleanup(now) {
      await ensure();
      await database.query(`DELETE FROM moviehub_catalogue_limits WHERE window_start < $1`, [now - 120000]);
      const [lock, evict] = budgetStatements();
      await database.transaction([lock, { text: `DELETE FROM moviehub_catalogue_cache WHERE lease_until <= $1 AND
        (stale_until < $1 OR cache_key IN (SELECT cache_key FROM moviehub_catalogue_cache
          WHERE lease_until <= $1 ORDER BY fresh_until DESC OFFSET 2000))`, parameters: [now] }, evict]);
    },
  };
}

module.exports = { createCatalogueStore, MAX_CATALOGUE_BYTES };
