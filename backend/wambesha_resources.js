const MAX_RESPONSE_BYTES = 1024 * 1024;
const MAX_CACHE_BYTES = 8 * 1024 * 1024;
const MAX_CACHE_ENTRIES = 128;
const MAX_PROVIDER_TASKS = 8;
const PROVIDER_TIMEOUT_MS = 15000;
const SOURCE_TTL_MS = 300000;
const EMPTY_TTL_MS = 30000;
const EXPIRY_MARGIN_MS = 30000;

async function withAbort(promise, signal) {
  let onAbort;
  try {
    // The operation may already have started when its deadline expires.
    // Keep its rejection observed even when the signal was already aborted.
    if (signal.aborted) { void Promise.resolve(promise).catch(() => {}); }
    signal.throwIfAborted();
    const aborted = new Promise((_, reject) => {
      onAbort = () => reject(signal.reason);
      signal.addEventListener('abort', onAbort, { once: true });
    });
    return await Promise.race([promise, aborted]);
  } finally {
    if (onAbort) signal.removeEventListener('abort', onAbort);
  }
}

function cancelBody(body) {
  // Never wait on an untrusted stream's cancellation promise.
  try { void body?.cancel().catch(() => {}); } catch (_) { /* Already closed/locked. */ }
}

async function readProviderJson(response, signal) {
  const length = response.headers.get('content-length');
  if (length && /^\d+$/.test(length) && Number(length) > MAX_RESPONSE_BYTES) {
    cancelBody(response.body);
    throw new Error('Provider response exceeded its limit.');
  }
  if (!response.body) throw new Error('Provider response has no body.');
  const reader = response.body.getReader();
  // A byte budget alone cannot bound an array containing millions of tiny
  // chunks. Copy into one fixed buffer instead of retaining each chunk object.
  const buffer = Buffer.allocUnsafe(MAX_RESPONSE_BYTES);
  let bytes = 0;
  try {
    while (true) {
      const { done, value } = await withAbort(reader.read(), signal);
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_RESPONSE_BYTES) throw new Error('Provider response exceeded its limit.');
      buffer.set(value, bytes - value.byteLength);
    }
    // The decoded stream is measured even when headers are absent, compressed
    // or inaccurate. Parse only after the complete body fits the byte budget.
    const data = JSON.parse(new TextDecoder('utf-8', { fatal: true })
      .decode(buffer.subarray(0, bytes)));
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      throw new Error('Provider response is not a JSON object.');
    }
    return data;
  } catch (error) {
    cancelBody(reader);
    throw error;
  } finally {
    reader.releaseLock();
  }
}

function createSourceCache({ now = Date.now, maxBytes = MAX_CACHE_BYTES,
  maxEntries = MAX_CACHE_ENTRIES } = {}) {
  if (!Number.isSafeInteger(maxBytes) || maxBytes < 1 || maxBytes > MAX_CACHE_BYTES ||
      !Number.isSafeInteger(maxEntries) || maxEntries < 1 || maxEntries > MAX_CACHE_ENTRIES) {
    throw new RangeError('Invalid source cache limits.');
  }
  const entries = new Map();
  let bytes = 0;
  function remove(key) {
    const entry = entries.get(key);
    if (entry) { bytes -= entry.body.length; entries.delete(key); }
  }
  function prune() {
    const time = now();
    for (const [key, entry] of entries) if (entry.expiresAt <= time) remove(key);
  }
  return {
    get(key) {
      prune();
      const entry = entries.get(key);
      if (!entry) return undefined;
      entries.delete(key); entries.set(key, entry);
      return entry.body;
    },
    set(key, data) {
      prune();
      const time = now();
      const sources = data.sources;
      let expiresAt = time + (sources.length ? SOURCE_TTL_MS : EMPTY_TTL_MS);
      for (const source of sources) {
        if (source.expires_at) expiresAt = Math.min(expiresAt,
          Date.parse(source.expires_at) - EXPIRY_MARGIN_MS);
      }
      const body = Buffer.from(JSON.stringify(data));
      remove(key);
      if (!Number.isFinite(expiresAt) || expiresAt <= time ||
          body.length > Math.min(maxBytes, MAX_RESPONSE_BYTES)) return;
      while (entries.size && (entries.size >= maxEntries || bytes + body.length > maxBytes)) {
        remove(entries.keys().next().value);
      }
      entries.set(key, { body, expiresAt }); bytes += body.length;
    },
    stats() { prune(); return { entries: entries.size, bytes }; },
  };
}

module.exports = { readProviderJson, withAbort, cancelBody, createSourceCache,
  MAX_RESPONSE_BYTES, MAX_CACHE_BYTES, MAX_CACHE_ENTRIES, MAX_PROVIDER_TASKS,
  PROVIDER_TIMEOUT_MS, EXPIRY_MARGIN_MS };
