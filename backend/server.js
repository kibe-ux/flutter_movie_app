const path = require("path");
require("dotenv").config({ path: path.join(__dirname, ".env") });

const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const mime = require("mime");
const fs = require("fs");
const { attachRequestTrace, upstreamTrace } = require("./upstream_diagnostics");
const { database, NeonDatabaseError } = require("./neon_database");
const { applicationDefault, getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { registerRewardsRoutes } = require("./rewards");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET;
const MOVIES_DIR = path.join(__dirname, "movies");
const FILMS365_BASE_URL = "https://www.films365.org";
const SUPPORTED_MOVIE_EXTENSIONS = new Set([".mp4", ".mkv", ".mov", ".avi", ".webm"]);
const BYTE_UNITS = ["B", "KB", "MB", "GB", "TB"];
const MOVIE_FILENAME_PATTERN = /^(.*?)[.\s_-]+((?:19|20)\d{2})(?:[.\s_-]+(\d{3,4}p))?/i;
const FILMS365_ENDPOINTS = new Map([
  ["trending", "GET"],
  ["popular", "GET"],
  ["latest", "GET"],
  ["explore", "GET"],
  ["details", "GET"],
  ["search", "POST"],
  ["person", "GET"],
  ["details/torrent-link", "POST"],
]);

app.use(cors());

function getLoggedApiEndpoint(pathname) {
  const mobileEndpoint = pathname.replace(/^\/mobile\//, "");
  if (pathname.startsWith("/mobile/") && FILMS365_ENDPOINTS.has(mobileEndpoint)) {
    return `/api/mobile/${mobileEndpoint}`;
  }
  if (pathname === "/movies") return "/api/movies";
  if (/^\/movies\/[^/]+$/.test(pathname)) return "/api/movies/:id";
  if (pathname === "/download/request") return "/api/download/request";
  if (pathname === "/download/stream") return "/api/download/stream";
  return "/api/other";
}

function logApiRequest(req, res, next) {
  attachRequestTrace(req, res);
  res.set("X-MovieHub-Response-Source", "node-backend");
  const pathname = req.path;
  res.on("finish", () => {
    console.log(JSON.stringify({
      endpoint: getLoggedApiEndpoint(pathname),
      status: res.statusCode,
      source: res.get("X-MovieHub-Response-Source"),
      requestId: req.movieHubRequestId,
    }));
  });
  next();
}

app.use("/api", logApiRequest);

function getFirebaseAdminAuth() {
  const projectId =
    process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) {
    throw new Error("FIREBASE_PROJECT_ID is not configured.");
  }

  const appName = "films365-proxy";
  const firebaseApp =
    getApps().find((candidate) => candidate.name === appName) ||
    initializeApp(
      {
        credential: applicationDefault(),
        projectId,
      },
      appName
    );
  return getAuth(firebaseApp);
}

async function requireFirebaseUser(req, res, next) {
  res.set("X-MovieHub-Response-Source", "firebase-auth");
  const authorization = req.header("authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    console.warn("Firebase authorization rejected: missing-bearer-token");
    return res.status(401).json({ error: "A Firebase ID token is required." });
  }

  try {
    req.firebaseUser = await getFirebaseAdminAuth().verifyIdToken(match[1]);
    res.set("X-MovieHub-Response-Source", "node-backend");
    return next();
  } catch (error) {
    const code = error && error.code;
    const invalidToken =
      typeof code === "string" &&
      (code.startsWith("auth/id-token-") ||
        [
          "auth/argument-error",
          "auth/invalid-id-token",
          "auth/user-disabled",
          "auth/user-not-found",
          "auth/tenant-id-mismatch",
        ].includes(code));
    if (invalidToken) {
      console.warn("Firebase authorization rejected:", code);
      return res.status(401).json({ error: "The Firebase ID token is invalid." });
    }

    console.error("Firebase ID-token verification is unavailable.");
    return res.status(503).json({ error: "Authentication service is unavailable." });
  }
}

function createFilms365Url(req, endpoint) {
  const url = new URL(`/api/mobile/${endpoint}`, FILMS365_BASE_URL);
  url.search = new URL(req.originalUrl, "http://localhost").search;
  return url;
}

function createFilms365Headers(req, apiKey) {
  const headers = { Authorization: `ApiKey ${apiKey}` };
  const contentType = req.header("content-type");
  if (contentType) headers["Content-Type"] = contentType;
  return headers;
}

function logUpstreamResponse({ req, endpoint, url, credential, response, startedAt }) {
  const trace = upstreamTrace({ req, endpoint, url, credential, response, startedAt });
  const prefix = response.ok ? "UPSTREAM_RESULT" : "UPSTREAM_FAIL";
  const log = response.ok ? console.log : console.error;
  log(`${prefix} ${JSON.stringify(trace)}`);
}

async function proxyFilms365Request(req, res, endpoint = req.params.endpoint) {
  attachRequestTrace(req, res);
  const expectedMethod = FILMS365_ENDPOINTS.get(endpoint);
  if (!expectedMethod) {
    return res.status(404).json({ error: "Unknown FILMS365 endpoint." });
  }
  if (req.method !== expectedMethod) {
    res.set("Allow", expectedMethod);
    return res.status(405).json({ error: "Method not allowed for this endpoint." });
  }

  const apiKey = process.env.FILMS365_API_KEY?.trim();
  if (!apiKey) {
    return res.status(503).json({ error: "FILMS365 is not configured on the server." });
  }

  const upstreamUrl = createFilms365Url(req, endpoint);
  const headers = createFilms365Headers(req, apiKey);

  const startedAt = Date.now();
  try {
    const upstreamResponse = await fetch(upstreamUrl, {
      method: expectedMethod,
      headers,
      body: expectedMethod === "POST" ? req.body : undefined,
      redirect: "error",
      signal: AbortSignal.timeout(30000),
    });
    logUpstreamResponse({
      req,
      endpoint,
      url: upstreamUrl,
      credential: apiKey,
      response: upstreamResponse,
      startedAt,
    });
    const responseBody = Buffer.from(await upstreamResponse.arrayBuffer());
    res.set("X-MovieHub-Response-Source", "films365");
    // Forward response bytes unchanged; response bodies are not logged.
    const upstreamContentType = upstreamResponse.headers.get("content-type");
    if (upstreamContentType) res.set("Content-Type", upstreamContentType);
    return res.status(upstreamResponse.status).send(responseBody);
  } catch (error) {
    console.error(`UPSTREAM_FAIL ${JSON.stringify(upstreamTrace({ req, endpoint,
      url: upstreamUrl, credential: apiKey, startedAt,
      failure: error?.name === "TimeoutError" ? "timeout" : "transport-error" }))}`);
    if (error && error.name === "TimeoutError") {
      return res.status(504).json({ error: "FILMS365 request timed out." });
    }
    const errorName =
      error && typeof error.name === "string" ? error.name : "UnknownError";
    console.error("FILMS365 upstream request failed:", errorName);
    return res.status(502).json({ error: "FILMS365 is unavailable." });
  }
}

app.use(
  "/api/mobile",
  express.raw({ type: "*/*", limit: "1mb" }),
  requireFirebaseUser,
  (req, res) =>
    proxyFilms365Request(req, res, req.path.replace(/^\/+/, ""))
);

app.locals.proxyFilms365Request = proxyFilms365Request;

app.use(express.json());

registerRewardsRoutes(app, {
  authenticate: requireFirebaseUser,
  firebaseApp: () => getFirebaseAdminAuth().app,
});

function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < BYTE_UNITS.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(value < 10 && unit > 0 ? 1 : 0)} ${BYTE_UNITS[unit]}`;
}

function parseMovieFilename(fileName) {
  const ext = path.extname(fileName).toLowerCase();
  if (!SUPPORTED_MOVIE_EXTENSIONS.has(ext)) return null;

  const base = path.basename(fileName, ext);
  const match = base.match(MOVIE_FILENAME_PATTERN);
  if (!match) return null;

  const rawTitle = match[1].replace(/[._-]+/g, " ").trim();
  if (!rawTitle) return null;

  const year = Number(match[2]);
  const quality = (match[3] || "Unknown").toUpperCase();
  const id = `${rawTitle.toLowerCase().replace(/[^a-z0-9]+/g, "-")}-${year}`.replace(/^-+|-+$/g, "");

  return {
    id,
    title: rawTitle,
    year,
    quality,
  };
}

function walkMovieFiles(dir) {
  const files = [];
  if (!fs.existsSync(dir)) return files;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...walkMovieFiles(fullPath));
    } else if (entry.isFile()) {
      files.push(fullPath);
    }
  }
  return files;
}

function buildMovieCatalog() {
  const catalog = new Map();
  const filePaths = walkMovieFiles(MOVIES_DIR);

  for (const fullPath of filePaths) {
    const parsed = parseMovieFilename(path.basename(fullPath));
    if (!parsed) continue;

    const stat = fs.statSync(fullPath);
    const relativePath = path.relative(MOVIES_DIR, fullPath).replace(/\\/g, "/");

    if (!catalog.has(parsed.id)) {
      catalog.set(parsed.id, {
        id: parsed.id,
        title: parsed.title,
        year: parsed.year,
        poster: null,
        qualities: {},
      });
    }

    const movie = catalog.get(parsed.id);
    movie.qualities[parsed.quality] = {
      path: relativePath,
      size: stat.size,
      formattedSize: formatBytes(stat.size),
    };
  }

  return Array.from(catalog.values()).sort((a, b) =>
    a.title.localeCompare(b.title) || a.year - b.year
  );
}

function findMovieById(movieId) {
  const movies = buildMovieCatalog();
  return movies.find((movie) => movie.id === movieId) || null;
}

app.get("/health", (_req, res) => {
  res.json({
    status: "ok",
    timestamp: new Date().toISOString(),
    moviesDir: MOVIES_DIR,
  });
});

app.get("/api/database/health", requireFirebaseUser, async (_req, res) => {
  try {
    await database.checkConnection();
    return res.json({ status: "ok", database: "neon" });
  } catch (error) {
    return res.status(503).json({
      error: error instanceof NeonDatabaseError
        ? error.message : "The database is unavailable.",
    });
  }
});

app.get("/api/movies", requireFirebaseUser, (_req, res) => {
  const movies = buildMovieCatalog();
  res.json({ total: movies.length, movies });
});

app.get("/api/movies/:id", requireFirebaseUser, (req, res) => {
  const movie = findMovieById(req.params.id);
  if (!movie) {
    return res.status(404).json({ error: "Movie not found" });
  }
  return res.json(movie);
});

app.post("/api/download/request", requireFirebaseUser, (req, res) => {
  if (!JWT_SECRET) {
    return res.status(503).json({ error: "Download signing is not configured." });
  }
  const { movieId, quality } = req.body || {};
  if (!movieId || !quality) {
    return res.status(400).json({ error: "movieId and quality are required" });
  }

  const movie = findMovieById(movieId);
  if (!movie) {
    return res.status(404).json({ error: "Movie not found" });
  }

  const qualityKey = Object.keys(movie.qualities).find(
    (q) => q.toLowerCase() === String(quality).toLowerCase()
  );
  if (!qualityKey) {
    return res.status(400).json({ error: "Requested quality is not available" });
  }

  const qualityInfo = movie.qualities[qualityKey];
  const token = jwt.sign(
    {
      movieId: movie.id,
      quality: qualityKey,
      path: qualityInfo.path,
    },
    JWT_SECRET,
    { expiresIn: "1h" }
  );

  const signedUrl =
    `${req.protocol}://${req.get("host")}/api/download/stream` +
    `?token=${encodeURIComponent(token)}`;

  return res.json({
    movieId: movie.id,
    quality: qualityKey,
    fileName: path.basename(qualityInfo.path),
    size: qualityInfo.size,
    formattedSize: qualityInfo.formattedSize,
    expiresInSeconds: 3600,
    downloadUrl: signedUrl,
  });
});

app.get("/api/download/stream", (req, res) => {
  const token = req.query.token;
  if (!token) {
    return res.status(400).json({ error: "Missing token" });
  }

  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch (_err) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }

  const resolvedPath = path.resolve(MOVIES_DIR, payload.path || "");
  if (!resolvedPath.startsWith(path.resolve(MOVIES_DIR))) {
    return res.status(403).json({ error: "Invalid file path" });
  }
  if (!fs.existsSync(resolvedPath)) {
    return res.status(404).json({ error: "Movie file not found" });
  }

  const stat = fs.statSync(resolvedPath);
  const total = stat.size;
  const contentType = mime.getType(resolvedPath) || "application/octet-stream";
  const range = req.headers.range;

  if (range) {
    const match = range.match(/bytes=(\d*)-(\d*)/);
    if (!match) {
      return res.status(416).set("Content-Range", `bytes */${total}`).end();
    }

    const start = match[1] ? parseInt(match[1], 10) : 0;
    const end = match[2] ? parseInt(match[2], 10) : total - 1;
    if (Number.isNaN(start) || Number.isNaN(end) || start > end || end >= total) {
      return res.status(416).set("Content-Range", `bytes */${total}`).end();
    }

    const chunkSize = end - start + 1;
    res.writeHead(206, {
      "Content-Range": `bytes ${start}-${end}/${total}`,
      "Accept-Ranges": "bytes",
      "Content-Length": chunkSize,
      "Content-Type": contentType,
      "Content-Disposition": `attachment; filename="${path.basename(resolvedPath)}"`,
    });
    return fs.createReadStream(resolvedPath, { start, end }).pipe(res);
  }

  res.writeHead(200, {
    "Content-Length": total,
    "Content-Type": contentType,
    "Accept-Ranges": "bytes",
    "Content-Disposition": `attachment; filename="${path.basename(resolvedPath)}"`,
  });
  return fs.createReadStream(resolvedPath).pipe(res);
});

if (require.main === module) {
  const server = app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`Movie download backend running on http://localhost:${PORT}`);
  });
  server.on("error", (error) => {
    if (error.code === "EADDRINUSE") {
      console.error(`Port ${PORT} is already in use. Stop the existing backend before running npm start again.`);
    } else {
      console.error("Backend could not start.");
    }
    process.exitCode = 1;
  });
}

module.exports = app;
