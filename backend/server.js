const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const mime = require("mime");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const API_KEY = process.env.API_KEY || "dev-api-key";
const JWT_SECRET = process.env.JWT_SECRET || "replace-with-a-secure-secret";
const MOVIES_DIR = path.join(__dirname, "movies");

app.use(cors());
app.use(express.json());

function authMiddleware(req, res, next) {
  const key = req.header("x-api-key") || req.query.apiKey;
  if (!key || key !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized: invalid API key" });
  }
  return next();
}

app.use(authMiddleware);

function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(value < 10 && unit > 0 ? 1 : 0)} ${units[unit]}`;
}

function parseMovieFilename(fileName) {
  const ext = path.extname(fileName).toLowerCase();
  const supported = new Set([".mp4", ".mkv", ".mov", ".avi", ".webm"]);
  if (!supported.has(ext)) return null;

  const base = path.basename(fileName, ext);
  const match = base.match(/^(.*?)[.\s_-]+((?:19|20)\d{2})(?:[.\s_-]+(\d{3,4}p))?/i);
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

app.get("/api/movies", (_req, res) => {
  const movies = buildMovieCatalog();
  res.json({ total: movies.length, movies });
});

app.get("/api/movies/:id", (req, res) => {
  const movie = findMovieById(req.params.id);
  if (!movie) {
    return res.status(404).json({ error: "Movie not found" });
  }
  return res.json(movie);
});

app.post("/api/download/request", (req, res) => {
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
    `?token=${encodeURIComponent(token)}&apiKey=${encodeURIComponent(API_KEY)}`;

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

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Movie download backend running on http://localhost:${PORT}`);
});
