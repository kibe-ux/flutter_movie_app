const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '../.env'), quiet: true });

// Read-only comparison. Never print credentials, response bodies or file URLs.
async function main() {
  const key = process.env.FILMS365_API_KEY?.trim();
  if (!key) throw new Error('missing-configuration');
  async function request(endpoint, params, body) {
    const url = new URL(`/api/mobile/${endpoint}`, 'https://www.films365.org');
    url.search = new URLSearchParams(params).toString();
    const response = await fetch(url, {
      method: body ? 'POST' : 'GET',
      headers: { Authorization: `ApiKey ${key}`,
        ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
      redirect: 'error', signal: AbortSignal.timeout(15000),
    });
    const json = await response.json();
    return { status: response.status, json };
  }
  const query = process.argv.slice(2).find(value => value !== '--probe');
  const probe = process.argv.includes('--probe');
  const catalogue = query
    ? await request('search', {}, { query })
    : await request('popular', { type: 'movie', page: '1' });
  const movies = query ? catalogue.json.results?.movies : catalogue.json.results;
  console.log(JSON.stringify({ catalogueStatus: catalogue.status }));
  for (const movie of (movies || []).slice(0, 5)) {
    const summary = { title: movie.title, movieTmdbId: movie.tmdbId };
    for (const field of ['id', 'tmdbId']) {
      if (!movie[field]) continue;
      const result = await request('details', { type: 'movie', [field]: movie[field] });
      const data = result.json.data;
      summary[field] = { status: result.status,
        hasDetails: !!data && Object.keys(data).length > 0,
        hasDownload: typeof data?.downloadUrl === 'string' && /^https?:\/\//.test(data.downloadUrl.trim()),
        futureRelease: typeof data?.releaseDate === 'string' && data.releaseDate.slice(0, 10) > new Date().toISOString().slice(0, 10) };
      if (probe && summary[field].hasDownload) {
        try {
          const file = await fetch(data.downloadUrl.trim(), {
            headers: { Range: 'bytes=0-1023' }, signal: AbortSignal.timeout(15000),
          });
          summary[field].fileProbe = { status: file.status,
            contentType: file.headers.get('content-type')?.split(';')[0] || null };
          await file.body?.cancel();
        } catch (_) {
          summary[field].fileProbe = { error: 'transfer-unavailable' };
        }
      }
    }
    console.log(JSON.stringify(summary));
  }
}
main().catch(() => { console.error('Movie comparison could not complete.'); process.exitCode = 1; });
