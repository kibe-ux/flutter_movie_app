const assert = require("node:assert/strict");
const test = require("node:test");
const { createDatabase, NeonDatabaseError } = require("../neon_database");

test("a missing database configuration never opens a connection", async () => {
  const database = createDatabase({
    connectionString: () => "",
    createClient() { assert.fail("An unconfigured database must not be contacted"); },
  });
  await assert.rejects(database.checkConnection(), (error) =>
    error instanceof NeonDatabaseError && error.code === "NOT_CONFIGURED");
});

test("database passwords are never included in configuration or driver errors", async () => {
  for (const url of [
    "https://user:private-password@example.org/database",
    "postgresql://user:private-password@example.neon.tech/neondb?sslmode=require",
  ]) {
    const database = createDatabase({
      connectionString: () => url,
      createClient() {
        return { query: async () => { throw new Error(`Sensitive connection: ${url}`); } };
      },
    });
    await assert.rejects(database.checkConnection(), (error) => {
      assert.ok(error instanceof NeonDatabaseError);
      assert.equal(error.message.includes("private-password"), false);
      assert.equal(error.message.includes(url), false);
      assert.equal(error.cause, undefined);
      return true;
    });
  }
});

test("queries pass SQL parameters separately and the health check requires a database response", async () => {
  const queries = [];
  const database = createDatabase({
    connectionString: () => "postgresql://test:test@example.neon.tech/neondb?sslmode=require",
    createClient() {
      return { query: async (text, parameters) => {
        queries.push({ text, parameters });
        return text === "SELECT 1 AS connected" ? [{ connected: 1 }] : [];
      } };
    },
  });
  const value = "'; DROP TABLE movies; --";
  await database.query("SELECT $1::text AS title", [value]);
  assert.deepEqual(queries[0], { text: "SELECT $1::text AS title", parameters: [value] });
  assert.deepEqual(await database.checkConnection(), { connected: true });
});

test("a failed query can be retried and an invalid health response is not reported as connected", async () => {
  let calls = 0;
  const database = createDatabase({
    connectionString: () => "postgresql://test:test@example.neon.tech/neondb?sslmode=require",
    createClient() {
      return { query: async () => {
        if (++calls === 1) throw new Error("Temporary network problem");
        return calls === 2 ? [] : [{ connected: 1 }];
      } };
    },
  });
  await assert.rejects(database.checkConnection(), { code: "UNAVAILABLE" });
  await assert.rejects(database.checkConnection(), { code: "UNAVAILABLE" });
  assert.deepEqual(await database.checkConnection(), { connected: true });
});
