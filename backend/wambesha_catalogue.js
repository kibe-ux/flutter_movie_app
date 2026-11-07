// Public catalogue metadata only. Source verification stays authenticated in
// wambesha.js; no source URLs or account responses enter the shared cache.
const { readProviderJson } = require('./wambesha_resources');

const genres = new Set(['action', 'adventure', 'animation', 'biography', 'comedy',
  'crime', 'documentary', 'drama', 'family', 'fantasy', 'film-noir', 'game-show',
  'history', 'horror', 'kids', 'music', 'musical', 'mystery', 'news', 'reality',
  'romance', 'science-fiction', 'short', 'soap', 'sport', 'talk-show', 'thriller',
  'tv-movie', 'war', 'western']);

function discoveryParameters(query) {
  const allowed = new Set(['type', 'genre', 'sort', 'cursor', 'page', 'language']);
  if (Object.entries(query).some(([key, value]) => !allowed.has(key) || typeof value !== 'string')) {
    throw new Error('Unsupported catalogue parameters.');
  }
  const type = query.type || 'movie';
  const sort = query.sort || 'popularity';
  const page = query.page || '1';
  if (!['movie', 'series'].includes(type) ||
      !['popularity', 'rating', 'newest', 'alphabetical'].includes(sort) ||
      !/^[1-9]\d{0,3}$/.test(page) ||
      (query.language !== undefined && query.language !== 'en-US') ||
      (query.cursor !== undefined && !/^[A-Za-z0-9_=-]{1,512}$/.test(query.cursor)) ||
      (Number(page) > 1 && !query.cursor)) throw new Error('Invalid catalogue parameters.');
  const selected = query.genre ? [...new Set(query.genre.split(','))].sort() : [];
  if (selected.length > 5 || selected.some(genre => !genres.has(genre))) {
    throw new Error('Invalid catalogue genre.');
  }
  const params = new URLSearchParams({ type, sort, page, language: 'en-US' });
  if (selected.length) params.set('genre', selected.join(','));
  if (query.cursor) params.set('cursor', query.cursor);
  params.sort();
  return params;
}

function imageUrl(image) {
  if (typeof image?.url !== 'string' || image.url.length > 4096) return null;
  try {
    const url = new URL(image.url);
    return url.protocol === 'https:' && !url.username && !url.password ? image.url : null;
  } catch { return null; }
}

function normalize(record, expectedType, now) {
  if (!record || record.type !== expectedType ||
      !new RegExp(expectedType === 'movie' ? '^mv_[A-Za-z0-9]{1,40}$' : '^sr_[A-Za-z0-9]{1,40}$').test(record.id)) return null;
  const idValue = record.external_ids?.tmdb_id;
  if (!/^\d+$/.test(String(idValue))) return null;
  const id = Number(idValue);
  if (!Number.isSafeInteger(id) || id < 1 || typeof record.title !== 'string') return null;
  const date = expectedType === 'movie' ? record.release_date : record.first_air_date;
  if (['upcoming', 'announced', 'in_production', 'planned'].includes(record.status) ||
      (Number.isFinite(Date.parse(date)) && Date.parse(date) > now) ||
      (Number.isInteger(record.year) && record.year > new Date(now).getUTCFullYear())) return null;
  const rating = (record.ratings || []).find(item => item.source === 'TMDB' && item.max_score === 10) ||
    (record.ratings || []).find(item => item.source === 'IMDB' && item.max_score === 10);
  return {
    id, wambesha_id: record.id, media_type: expectedType === 'movie' ? 'movie' : 'tv',
    title: record.title, name: record.title, original_title: record.original_title,
    overview: typeof record.synopsis === 'string' ? record.synopsis : '',
    year: record.year, release_date: record.release_date, first_air_date: record.first_air_date,
    catalogue_status: record.status, poster_url: imageUrl(record.poster), backdrop_url: imageUrl(record.backdrop),
    vote_average: typeof rating?.score === 'number' ? rating.score : 0,
    vote_count: Number.isSafeInteger(rating?.vote_count) ? rating.vote_count : 0,
  };
}

async function fetchWambeshaCatalogue(request, { fetchImpl, key, beforeFetch, now = Date.now }) {
  const signal = AbortSignal.timeout(15000);
  async function get(path, params) {
    await beforeFetch();
    const url = new URL(`https://api.wambesha.com/v1/${path}`);
    url.search = params.toString();
    const response = await fetchImpl(url, { headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' },
      redirect: 'error', signal });
    if (!response.ok) { try { void response.body?.cancel().catch(() => {}); } catch {} throw new Error('Catalogue unavailable.'); }
    return readProviderJson(response, signal);
  }
  const params = new URLSearchParams(request.params);
  params.delete('page');
  params.set('language', 'en');
  params.set('limit', '20');
  const discovery = await get('discover', params);
  if (!Array.isArray(discovery.items)) throw new Error('Invalid catalogue response.');
  const prefix = params.get('type') === 'movie' ? 'mv_' : 'sr_';
  const ids = [...new Set(discovery.items.map(item => item?.id)
    .filter(id => typeof id === 'string' && id.startsWith(prefix) && /^(mv|sr)_[A-Za-z0-9]{1,40}$/.test(id)))].slice(0, 20);
  const full = ids.length ? await get('titles', new URLSearchParams({ ids: ids.join(','), language: 'en' })) : { items: [] };
  if (!Array.isArray(full.items)) throw new Error('Invalid title response.');
  const byId = new Map(full.items.filter(item => item && typeof item === 'object').map(item => [item.id, item]));
  const results = ids.map(id => normalize(byId.get(id), params.get('type'), now())).filter(Boolean);
  const next = typeof discovery.next_cursor === 'string' && /^[A-Za-z0-9_=-]{1,512}$/.test(discovery.next_cursor) &&
    discovery.next_cursor !== params.get('cursor') ? discovery.next_cursor : null;
  return { page: Number(request.params.get('page')), results, next_cursor: next,
    has_more: next !== null, catalogue_provider: 'wambesha' };
}

module.exports = { discoveryParameters, fetchWambeshaCatalogue };
