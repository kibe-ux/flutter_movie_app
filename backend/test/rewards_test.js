const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { createRewards, createSsvVerifier, registerRewardsRoutes } = require("../rewards");

// Minimal transactional store: commits only if the callback succeeds. Serial
// transactions also model the SDK's conflict retry semantics for these tests.
function store() {
  const documents = new Map();
  let tail = Promise.resolve();
  const reference = (path) => ({
    path,
    get: async () => ({ exists: documents.has(path), data: () => documents.get(path) }),
    collection: (name) => ({ doc: (id) => reference(`${path}/${name}/${id}`) }),
  });
  return {
    documents,
    collection: (name) => ({ doc: (id) => reference(`${name}/${id}`) }),
    runTransaction: (callback) => {
      const run = tail.then(async () => {
        const writes = [];
        const result = await callback({
          get: (ref) => ref.get(),
          set: (ref, data, options) => writes.push([ref.path, data, options]),
        });
        for (const [path, data, options] of writes) documents.set(path,
          options?.merge ? { ...documents.get(path), ...data } : data);
        return result;
      });
      tail = run.catch(() => {});
      return run;
    },
  };
}
const unit = "ca-app-pub-publisher/1234";
test("reward routes reject guests and anonymous accounts before database access", async (t) => {
  const express = require("express");
  const app = express();
  app.use(express.json());
  let databaseAccess = 0;
  registerRewardsRoutes(app, {
    firebaseApp: () => { databaseAccess++; throw new Error("Unexpected database access"); },
    authenticate: (req, res, next) => {
      if (!req.header("authorization")) return res.sendStatus(401);
      req.firebaseUser = { uid: "viewer", firebase: { sign_in_provider: "anonymous" } };
      next();
    },
  });
  const server = app.listen(0, "127.0.0.1");
  await new Promise((resolve) => server.once("listening", resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [path, method] of [["wallet", "GET"], ["session", "POST"], ["cancel", "POST"], ["redeem", "POST"]]) {
    assert.equal((await fetch(`${base}/api/rewards/${path}`, { method })).status, 401);
    assert.equal((await fetch(`${base}/api/rewards/${path}`, { method, headers: { authorization: "anonymous" } })).status, 403);
  }
  assert.equal((await fetch(`${base}/api/rewards/ssv`)).status, 400);
  assert.equal(databaseAccess, 0);
});
function setup() {
  const db = store();
  let time = 1700000000000;
  const rewards = createRewards({ db, now: () => time, units: () => [unit], enabled: () => true });
  return { db, rewards, now: () => time, advance: (ms) => { time += ms; } };
}
const event = (session, now, changes = {}) => ({ user_id: "viewer", custom_data: session.id,
  ad_unit: "1234", transaction_id: "event_one", timestamp: String(now), reward_amount: "10", ...changes });

test("wallet is account-bound and configured offers are server-owned", async () => {
  const { rewards } = setup();
  const wallet = await rewards.wallet("viewer");
  assert.equal(wallet.coins, 0);
  assert.equal(wallet.coinsPerAd, 10);
  assert.equal(wallet.offers[0].coins, 30);
  assert.equal((await rewards.wallet("other")).adFreeUntil, 0);
});
test("disabled rewards never start an ad session", async () => {
  const rewards = createRewards({ db: store() });
  await assert.rejects(rewards.session("viewer", unit), { status: 503 });
});
test("only allowlisted ad units create sessions; pending session cannot launch twice", async () => {
  const { rewards } = setup();
  await assert.rejects(rewards.session("viewer", "other"), { status: 400 });
  await rewards.session("viewer", unit);
  await assert.rejects(rewards.session("viewer", unit), { status: 409 });
});
test("duplicate callbacks and different events for the same session cannot double-credit", async () => {
  const { rewards, now } = setup();
  const session = await rewards.session("viewer", unit);
  await Promise.all([rewards.credit(event(session, now())), rewards.credit(event(session, now()))]);
  assert.equal((await rewards.wallet("viewer")).coins, 10);
  await assert.rejects(rewards.credit(event(session, now(), { transaction_id: "other_event" })), { status: 400 });
  assert.equal((await rewards.wallet("viewer")).coins, 10);
});
test("wrong account, wrong unit and out-of-session timestamps do not earn coins", async () => {
  const { rewards, now } = setup();
  const session = await rewards.session("viewer", unit);
  for (const changes of [{ user_id: "other" }, { ad_unit: "999" }, { timestamp: String(now() + 3600000) }]) {
    await assert.rejects(rewards.credit(event(session, now(), changes)), { status: 400 });
  }
  assert.equal((await rewards.wallet("viewer")).coins, 0);
});
test("a late callback still pays its original session after cancellation", async () => {
  const { rewards, now } = setup();
  const session = await rewards.session("viewer", unit);
  await rewards.cancel("viewer", session.id);
  const next = await rewards.session("viewer", unit);
  await rewards.credit(event(session, now()));
  assert.equal((await rewards.wallet("viewer")).coins, 10);
  assert.equal((await rewards.wallet("viewer")).pendingReward, true);
  await rewards.credit(event(next, now(), { transaction_id: "next_event" }));
  assert.equal((await rewards.wallet("viewer")).coins, 20);
});
test("redemption retries charge once and additional passes extend the current expiry", async () => {
  const { rewards, db, now } = setup();
  db.documents.set("reward_accounts/viewer", { coins: 100 });
  const id = "request_00000000001";
  await Promise.all([rewards.redeem("viewer", "hour", id), rewards.redeem("viewer", "hour", id)]);
  let wallet = await rewards.wallet("viewer");
  assert.equal(wallet.coins, 70);
  assert.equal(wallet.adFreeUntil, now() + 3600000);
  wallet = await rewards.redeem("viewer", "hour", "request_00000000002");
  assert.equal(wallet.coins, 40);
  assert.equal(wallet.adFreeUntil, now() + 7200000);
  await assert.rejects(rewards.session("viewer", unit), { status: 409 });
});
test("simultaneous redemptions cannot overspend and expiry uses server time", async () => {
  const { rewards, db, now, advance } = setup();
  db.documents.set("reward_accounts/viewer", { coins: 30 });
  const results = await Promise.allSettled([
    rewards.redeem("viewer", "hour", "request_00000000001"),
    rewards.redeem("viewer", "hour", "request_00000000002"),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal((await rewards.wallet("viewer")).coins, 0);
  advance(3600001);
  assert.ok((await rewards.wallet("viewer")).adFreeUntil < now());
  assert.ok(await rewards.session("viewer", unit));
});

test("SSV checks exact signed bytes, rejects tampering and caches trusted keys", async () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  let downloads = 0;
  const verify = createSsvVerifier({ fetcher: async () => {
    downloads++;
    return { ok: true, json: async () => ({ keys: [{ keyId: 42,
      pem: publicKey.export({ type: "spki", format: "pem" }) }] }) };
  } });
  const body = "ad_unit=1234&custom_data=session%20data&transaction_id=event&user_id=viewer";
  const sig = crypto.sign("sha256", Buffer.from(body), privateKey).toString("base64url");
  const url = `/api/rewards/ssv?${body}&signature=${sig}&key_id=42`;
  assert.equal((await verify(url)).custom_data, "session data");
  await verify(url);
  assert.equal(downloads, 1);
  await assert.rejects(verify(url.replace("viewer", "attacker")), { status: 400 });
  await assert.rejects(verify(url.replace("&signature=", "&user_id=other&signature=")), { status: 400 });
  await assert.rejects(verify("/api/rewards/ssv?user_id=viewer"), { status: 400 });
});
