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

  async function query(text, parameters = []) {
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
      return await client.query(text, parameters, {
        fetchOptions: { signal: AbortSignal.timeout(15000) },
      });
    } catch {
      // Driver errors can contain passwords, SQL parameters or connection URLs.
      throw new NeonDatabaseError("UNAVAILABLE");
    }
  }

  async function checkConnection() {
    const rows = await query("SELECT 1 AS connected");
    if (rows?.[0]?.connected !== 1) throw new NeonDatabaseError("UNAVAILABLE");
    return { connected: true };
  }

  return { query, checkConnection };
}

module.exports = {
  createDatabase,
  database: createDatabase(),
  NeonDatabaseError,
};
