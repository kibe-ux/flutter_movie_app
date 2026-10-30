const path = require('node:path');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
require('dotenv').config({ path: path.join(__dirname, '../.env'), quiet: true });

// Credentials go to curl over stdin, never command arguments or report output.
const key = process.env.FILMS365_API_KEY?.trim();
if (!key || /[\r\n]/.test(key)) {
  console.error('FILMS365_API_KEY is missing or invalid in backend/.env.');
  process.exit(1);
}
const report = { checkedAt: new Date().toISOString(), requests: [] };

function request(endpoint, parameters = {}) {
  const url = new URL(`/api/mobile/${endpoint}`, 'https://www.films365.org');
  url.search = new URLSearchParams(parameters).toString();
  const result = spawnSync('curl.exe', ['-q', '--silent', '--show-error',
    '--proto', '=https', '--max-time', '20', '--config', '-',
    '--write-out', '\n%{http_code}', url.href], {
    input: `header = ${JSON.stringify(`Authorization: ApiKey ${key}`)}\n`,
    encoding: 'utf8', windowsHide: true, maxBuffer: 10 * 1024 * 1024,
  });
  if (result.status !== 0) {
    report.requests.push({ endpoint, type: parameters.type, transportFailure: true });
    return null;
  }
  const separator = result.stdout.lastIndexOf('\n');
  const status = Number(result.stdout.slice(separator + 1));
  let body;
  try { body = JSON.parse(result.stdout.slice(0, separator)); }
  catch { body = null; }
  const entry = { endpoint, type: parameters.type, status,
    responseFields: body && typeof body === 'object' ? Object.keys(body) : [],
  };
  report.requests.push(entry);
  return { body, entry, ok: status >= 200 && status < 300 };
}

function videoSummary(details) {
  const found = [];
  function scan(value, current = '', depth = 0) {
    if (depth > 8 || value == null || typeof value !== 'object') return;
    for (const [field, item] of Object.entries(value)) {
      const fieldPath = current ? `${current}.${field}` : field;
      if (/video|trailer|stream|playback|download/i.test(field)) {
        const rows = Array.isArray(item) ? item : item?.results;
        found.push({ field: fieldPath,
          kind: Array.isArray(item) ? 'array' : typeof item,
          ...(Array.isArray(rows) ? { count: rows.length } : {}),
          ...(typeof item === 'string' ? { populated: Boolean(item.trim()) } : {}),
        });
      }
      scan(item, fieldPath, depth + 1);
    }
  }
  scan(details);
  const raw = details?.videos;
  const videos = Array.isArray(raw) ? raw : raw?.results;
  return { mediaFields: found, videos: Array.isArray(videos) ? videos.map(video => {
    const youtube = String(video.site).toLowerCase() === 'youtube' &&
      /^[A-Za-z0-9_-]{11}$/.test(video.key ?? '');
    return { name: String(video.name ?? '').slice(0, 160),
      site: String(video.site ?? '').slice(0, 30),
      type: String(video.type ?? '').slice(0, 30), official: video.official === true,
      ...(youtube ? { youtubeUrl: `https://www.youtube.com/watch?v=${video.key}` } : {}),
    };
  }) : [] };
}

try {
  const list = request('trending', { type: 'all', page: '1' });
  if (list?.ok) {
    const items = list.body?.results ?? [];
    list.entry.resultCount = Array.isArray(items) ? items.length : 0;
    for (const type of ['movie', 'tv']) {
      const item = Array.isArray(items) && items.find(item => item.type === type && item.id);
      if (!item) continue;
      const result = request('details', { type, id: item.id });
      if (!result) break;
      result.entry.title = String(item.title ?? item.name ?? '').slice(0, 160);
      if (result.ok) {
        const details = result.body?.data ?? result.body;
        result.entry.detailsFields = Object.keys(details ?? {});
        Object.assign(result.entry, videoSummary(details));
      }
      if ([401, 403].includes(result.entry.status)) break;
    }
  }
  const reportPath = path.join(__dirname, '../../reports/films365-videos-check.json');
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  const output = JSON.stringify(report, null, 2).split(key).join('[REDACTED]');
  fs.writeFileSync(reportPath, output + '\n');
  console.log(JSON.stringify({ checkedAt: report.checkedAt,
    requests: report.requests.map(entry => ({ endpoint: entry.endpoint,
      type: entry.type, status: entry.status, title: entry.title,
      videos: entry.videos, transportFailure: entry.transportFailure })),
    report: 'reports/films365-videos-check.json',
  }, null, 2).split(key).join('[REDACTED]'));
} catch {
  console.error('Video metadata inspection failed; no credentials were printed.');
  process.exitCode = 1;
}
