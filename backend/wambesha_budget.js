const { WambeshaLimitError } = require('./wambesha_limits');

function integer(name, fallback, max) {
  if (process.env[name] === undefined) return fallback;
  const value = Number(process.env[name]);
  if (!Number.isSafeInteger(value) || value < 0 || value > max) throw new Error(`Invalid ${name}.`);
  return value;
}

function periods(time, billingDay = 1) {
  const date = new Date(time);
  const day = date.toISOString().slice(0, 10);
  const month = day.slice(0, 7);
  const boundary = (year, monthIndex) => Date.UTC(year, monthIndex,
    Math.min(billingDay, new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate()));
  let year = date.getUTCFullYear(), index = date.getUTCMonth();
  if (time < boundary(year, index)) index--;
  const start = boundary(year, index);
  return { day, month, verificationMonth: new Date(start).toISOString().slice(0, 10) };
}

function createBudgetStore(database) {
  let ready;
  async function ensure() {
    if (!ready) ready = (async () => {
      await database.query(`CREATE TABLE IF NOT EXISTS moviehub_wambesha_budget (
        scope text PRIMARY KEY,
        call_month text NOT NULL DEFAULT '', call_month_used bigint NOT NULL DEFAULT 0,
        source_month text NOT NULL DEFAULT '', source_month_used bigint NOT NULL DEFAULT 0,
        call_day text NOT NULL DEFAULT '', call_day_used bigint NOT NULL DEFAULT 0,
        source_day text NOT NULL DEFAULT '', source_day_used bigint NOT NULL DEFAULT 0)`);
      await database.query(`CREATE TABLE IF NOT EXISTS moviehub_wambesha_usage (
        scope text NOT NULL, period text NOT NULL, event text NOT NULL, count bigint NOT NULL,
        PRIMARY KEY (scope, period, event))`);
    })().catch(error => { ready = null; throw error; });
    await ready;
  }
  return {
    async reserve(scope, buckets, initialUsage = {}) {
      await ensure();
      const initialParameters = [scope], initialColumns = ['scope'], initialValues = ['$1'];
      for (const [column, period] of buckets) {
        initialColumns.push(column, `${column}_used`);
        initialParameters.push(period, initialUsage[column] || 0);
        initialValues.push(`$${initialParameters.length - 1}`, `$${initialParameters.length}`);
      }
      await database.query(`INSERT INTO moviehub_wambesha_budget (${initialColumns.join(', ')})
        VALUES (${initialValues.join(', ')}) ON CONFLICT DO NOTHING`, initialParameters);
      const parameters = [scope], assignments = [], guards = [];
      for (const [column, period, units, limit] of buckets) {
        const offset = parameters.length;
        parameters.push(period, units, limit);
        const used = `(CASE WHEN ${column} = $${offset + 1} THEN ${column}_used ELSE 0 END + $${offset + 2})`;
        assignments.push(`${column} = $${offset + 1}`, `${column}_used = ${used}`);
        // A request delayed across midnight must not move a period backwards
        // and erase reservations already made in the new window.
        guards.push(`${column} <= $${offset + 1}`);
        // Keep the limit parameter typed even for zero-unit metadata calls.
        guards.push(`($${offset + 2}::bigint = 0 OR ${used} <= $${offset + 3}::bigint)`);
      }
      // One row lock and one conditional UPDATE: all four reservations succeed
      // together, even when several server instances race at the boundary.
      const rows = await database.query(`UPDATE moviehub_wambesha_budget SET ${assignments.join(', ')}
        WHERE scope = $1 AND ${guards.join(' AND ')} RETURNING scope`, parameters);
      return rows.length > 0;
    },
    async record(scope, period, event, amount) {
      await ensure();
      await database.query(`INSERT INTO moviehub_wambesha_usage (scope, period, event, count)
        VALUES ($1, $2, $3, $4) ON CONFLICT (scope, period, event) DO UPDATE
        SET count = moviehub_wambesha_usage.count + EXCLUDED.count`, [scope, period, event, amount]);
    },
    async report(scope) {
      await ensure();
      return {
        reservations: (await database.query('SELECT * FROM moviehub_wambesha_budget WHERE scope = $1', [scope]))[0] || null,
        events: await database.query(`SELECT period, event, count FROM moviehub_wambesha_usage
          WHERE scope = $1 ORDER BY period DESC, event LIMIT 240`, [scope]),
      };
    },
  };
}

function createWambeshaBudget({ database, store = createBudgetStore(database), now = Date.now,
  scope = process.env.WAMBESHA_BUDGET_SCOPE || 'default',
  callMonth = integer('WAMBESHA_MONTHLY_CALL_BUDGET', 45000, 100000000),
  sourceMonth = integer('WAMBESHA_MONTHLY_SOURCE_BUDGET', 900, 100000000),
  callDay = integer('WAMBESHA_DAILY_CALL_BUDGET', 9000, 100000000),
  sourceDay = integer('WAMBESHA_DAILY_SOURCE_BUDGET', 180, 100000000),
  billingDay = integer('WAMBESHA_VERIFICATION_RESET_DAY', 1, 31),
  initialUsage = {
    call_month: integer('WAMBESHA_INITIAL_MONTHLY_CALLS_USED', 0, 100000000),
    source_month: integer('WAMBESHA_INITIAL_MONTHLY_SOURCES_USED', 0, 100000000),
    call_day: integer('WAMBESHA_INITIAL_DAILY_CALLS_USED', 0, 100000000),
    source_day: integer('WAMBESHA_INITIAL_DAILY_SOURCES_USED', 0, 100000000),
  },
} = {}) {
  if (billingDay < 1) throw new Error('Invalid verification reset day.');
  const limits = { callMonth, sourceMonth, callDay, sourceDay, billingDay };
  return {
    async reserve(sources = false) {
      const period = periods(now(), billingDay);
      try {
        const accepted = await store.reserve(scope, [
          ['call_month', period.month, 1, callMonth],
          ['source_month', period.verificationMonth, sources ? 1 : 0, sourceMonth],
          ['call_day', period.day, 1, callDay],
          ['source_day', period.day, sources ? 1 : 0, sourceDay],
        ], initialUsage);
        if (!accepted) throw new WambeshaLimitError(503, 'Movie service allowance reached. Please try again later.', 3600);
      } catch (error) {
        if (error instanceof WambeshaLimitError) throw error;
        throw new WambeshaLimitError(503, 'Movie service usage check is unavailable.', 15);
      }
    },
    async record(event, fields = {}) {
      let metric = {
        'cache-hit': 'source_cache_hits', coalesced: 'source_coalesced',
        'metadata-cache-hit': 'metadata_cache_hits', 'quota-rejected': 'quota_rejections',
        'source-error': 'source_errors',
      }[event];
      if (event === 'shared-cache' && ['SHARED_HIT', 'SHARED_COALESCED'].includes(fields.cache)) metric = 'source_shared_hits';
      if (event === 'upstream-request') metric = fields.sources ? 'source_provider_calls' : 'metadata_provider_calls';
      if (event === 'verification') metric = fields.spent === 1 ? 'reported_verifications'
        : fields.spent === 0 ? 'reported_zero_verifications' : 'unknown_verification_responses';
      if (metric) await store.record(scope, periods(now(), billingDay).month, metric, 1);
    },
    async report() {
      const currentPeriods = periods(now(), billingDay);
      const data = await store.report(scope);
      const row = data.reservations || {};
      const remaining = (column, period, limit) => Math.max(0, limit -
        (row[column] === period ? Number(row[`${column}_used`]) : 0));
      return { limits, currentPeriods, ...data, remaining: {
        monthlyCalls: remaining('call_month', currentPeriods.month, callMonth),
        monthlySourceAttempts: remaining('source_month', currentPeriods.verificationMonth, sourceMonth),
        dailyCalls: remaining('call_day', currentPeriods.day, callDay),
        dailySourceAttempts: remaining('source_day', currentPeriods.day, sourceDay),
      } };
    },
  };
}

module.exports = { createWambeshaBudget, createBudgetStore, periods };
