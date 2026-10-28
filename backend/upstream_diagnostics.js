const { randomUUID } = require("node:crypto");

const backendInstance = randomUUID();
let previousCredential;
let credentialRevision = 0;

function attachRequestTrace(req, res) {
  req.movieHubRequestId ||= randomUUID();
  res.set("X-MovieHub-Request-Id", req.movieHubRequestId);
  res.set("X-MovieHub-Backend-Instance", backendInstance);
}

function cacheSummary(headers) {
  const cacheControl = headers?.get("cache-control") || "";
  const directives = cacheControl.match(/\b(?:public|private|no-cache|no-store|must-revalidate|proxy-revalidate|immutable|s-maxage=\d+|max-age=\d+)\b/gi);
  const cacheStatuses = new Set(["HIT", "MISS", "BYPASS", "DYNAMIC", "EXPIRED", "STALE", "REVALIDATED", "UPDATING"]);
  const cfStatus = (headers?.get("cf-cache-status") || "").toUpperCase();
  const proxyStatus = (headers?.get("x-cache") || "").split(/[ ,]/)[0].toUpperCase();
  const age = headers?.get("age") || "";
  return {
    cacheControl: directives?.join(", ") || null,
    cfCacheStatus: cacheStatuses.has(cfStatus) ? cfStatus : null,
    xCache: cacheStatuses.has(proxyStatus) ? proxyStatus : null,
    age: /^\d{1,12}$/.test(age) ? Number(age) : null,
  };
}

function upstreamTrace({ req, endpoint, url, credential, response, startedAt, failure }) {
  if (credential !== previousCredential) {
    previousCredential = credential;
    credentialRevision++;
  }
  const id = url.searchParams.get("id") || "";
  const tmdbId = url.searchParams.get("tmdbId") || "";
  const type = url.searchParams.get("type");
  return {
    timestamp: new Date().toISOString(),
    requestId: req.movieHubRequestId,
    backendInstance,
    // A counter scoped to this process; no key values or key hashes are logged.
    credentialRevision,
    endpoint: `/api/mobile/${endpoint}`,
    method: req.method,
    movieId: /^[a-zA-Z0-9_-]{1,128}$/.test(id) ? id : null,
    tmdbId: /^\d{1,12}$/.test(tmdbId) ? tmdbId : null,
    type: ["movie", "tv", "all"].includes(type) ? type : null,
    status: response?.status || null,
    durationMs: Math.max(0, Date.now() - startedAt),
    cache: cacheSummary(response?.headers),
    ...(failure ? { failure } : {}),
  };
}

module.exports = { attachRequestTrace, upstreamTrace };
