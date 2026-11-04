const { neon } = require("@neondatabase/serverless");

class NeonDatabaseError extends Error {
  constructor(code) {
    const messages = {
      NOT_CONFIGURED: "Set DATABASE_URL in backend/.env to connect your Neon database.",
      INVALID_CONFIGURATION: "DATABASE_URL must be a valid PostgreSQL connection string.",
      UNAVAILABLE: "The Neon database could not be reached. Check its status and connection settings.",
    };
    super(messages[code]);
    this.name = "NeonDatabaseError";
    this.code = code;
  }
}

function createDatabase({
  connectionString = () => process.env.DATABASE_URL,
  createClient = neon,
} = {}) {
  let cachedUrl;
  let client;

  function getClient() {
    const url = connectionString()?.trim();
    if (!url) throw new NeonDatabaseError("NOT_CONFIGURED");
    try {
      const parsed = new URL(url);
      if (!["postgres:", "postgresql:"].includes(parsed.protocol) || !parsed.hostname) {
        throw new Error("Invalid database URL");
      }
    } catch {
      throw new NeonDatabaseError("INVALID_CONFIGURATION");
    }

    try {
      if (!client || cachedUrl !== url) {
        client = createClient(url);
        cachedUrl = url;
      }
      return client;
    } catch {
      // Driver errors can contain passwords, SQL parameters or connection URLs.
      throw new NeonDatabaseError("UNAVAILABLE");
    }
  }

  async function query(text, parameters = []) {
    const sql = getClient();
    try {
      return await sql.query(text, parameters, {
        fetchOptions: { signal: AbortSignal.timeout(15000) },
      });
    } catch {
      throw new NeonDatabaseError("UNAVAILABLE");
    }
  }

  async function transaction(statements) {
    const sql = getClient();
    try {
      return await sql.transaction(statements.map(({ text, parameters = [] }) =>
        sql.query(text, parameters)), {
        // Each statement sees commits made while the first statement waited
        // for an advisory lock held by another cache writer.
        isolationLevel: "ReadCommitted",
        fetchOptions: { signal: AbortSignal.timeout(15000) },
      });
    } catch {
      throw new NeonDatabaseError("UNAVAILABLE");
    }
  }

  async function checkConnection() {
    const rows = await query("SELECT 1 AS connected");
    if (rows?.[0]?.connected !== 1) throw new NeonDatabaseError("UNAVAILABLE");
    return { connected: true };
  }

  return { query, transaction, checkConnection };
}

module.exports = {
  createDatabase,
  database: createDatabase(),
  NeonDatabaseError,
};
