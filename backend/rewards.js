const crypto = require("node:crypto");
const { getFirestore } = require("firebase-admin/firestore");

const OFFERS = Object.freeze([
  { id: "hour", coins: 30, hours: 1 },
  { id: "evening", coins: 80, hours: 3 },
  { id: "marathon", coins: 150, hours: 6 },
]);
const COINS_PER_AD = 10;
const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";

class RewardsError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

// Verify the original query bytes, never Express's decoded/reordered query map.
function createSsvVerifier({ fetcher = fetch, now = Date.now } = {}) {
  let keys = new Map();
  let fetchedAt = 0;
  let pending;
  let unknownRefreshAt = -Infinity;
  async function refresh() {
    if (!pending) pending = (async () => {
      const response = await fetcher(KEYS_URL, { signal: AbortSignal.timeout(10000) });
      if (!response.ok) throw new RewardsError(503, "Reward verification is unavailable.");
      const payload = await response.json();
      const next = new Map((payload.keys || []).map((key) => [String(key.keyId), key.pem]));
      if (!next.size) throw new RewardsError(503, "Reward verification is unavailable.");
      keys = next; fetchedAt = now();
    })().finally(() => { pending = null; });
    await pending;
  }
  return async function verify(originalUrl) {
    const query = originalUrl.slice(originalUrl.indexOf("?") + 1);
    const match = /^(.*)&signature=([^&]+)&key_id=(\d+)$/.exec(query);
    if (!match) throw new RewardsError(400, "Invalid reward verification.");
    const params = new URLSearchParams(query);
    if ([...params.keys()].some((key) => params.getAll(key).length !== 1)) {
      throw new RewardsError(400, "Invalid reward verification.");
    }
    if (!keys.size || now() - fetchedAt >= 6 * 3600000) await refresh();
    if (!keys.has(match[3]) && now() - unknownRefreshAt > 60000) {
      unknownRefreshAt = now();
      await refresh();
    }
    if (!keys.has(match[3])) throw new RewardsError(400, "Unknown verification key.");
    let valid = false;
    try {
      valid = crypto.verify("sha256", Buffer.from(match[1]), keys.get(match[3]),
        Buffer.from(decodeURIComponent(match[2]), "base64url"));
    } catch (_) { /* Reject malformed signatures without logging their contents. */ }
    if (!valid) throw new RewardsError(400, "Invalid reward verification.");
    return Object.fromEntries(params);
  };
}

function createRewards({ db, now = Date.now, units = () => [], enabled = () => false } = {}) {
  const database = () => typeof db === "function" ? db() : db;
  const account = (uid) => database().collection("reward_accounts").doc(uid);
  const configured = () => enabled() && units().length > 0;
  function requireEnabled() {
    if (!configured()) throw new RewardsError(503, "Cinema Rewards is being prepared. Please check back later.");
  }
  function publicWallet(data = {}) {
    return { coins: data.coins || 0, adFreeUntil: data.adFreeUntil || 0,
      serverTime: now(), enabled: configured(), coinsPerAd: COINS_PER_AD, offers: OFFERS,
      pendingReward: (data.pendingSession?.expiresAt || 0) > now() };
  }
  return {
    async wallet(uid) { return publicWallet((await account(uid).get()).data()); },
    async session(uid, unitId) {
      requireEnabled();
      if (!units().includes(unitId)) throw new RewardsError(400, "This rewarded ad is not available.");
      const ref = account(uid);
      // One active session per account limits duplicate launches across devices.
      return database().runTransaction(async (tx) => {
        const wallet = (await tx.get(ref)).data() || {};
        if ((wallet.adFreeUntil || 0) > now()) throw new RewardsError(409, "Your ad-free pass is already active.");
        const old = wallet.pendingSession;
        if (old && old.expiresAt > now()) throw new RewardsError(409, "Your previous reward is still pending. Please refresh shortly.");
        const session = { id: crypto.randomUUID(), unitId, issuedAt: now(), expiresAt: now() + 30 * 60000 };
        tx.set(ref, { pendingSession: session }, { merge: true });
        tx.set(database().collection("reward_sessions").doc(session.id), { ...session, uid, credited: false });
        return { ...session, uid };
      });
    },
    async cancel(uid, sessionId) {
      const ref = account(uid);
      await database().runTransaction(async (tx) => {
        const wallet = (await tx.get(ref)).data() || {};
        if (wallet.pendingSession?.id === sessionId) {
          tx.set(ref, { pendingSession: null }, { merge: true });
        }
      });
      return { cancelled: true };
    },
    async credit(event) {
      // Existing callbacks remain payable after acquisition is disabled.
      const { user_id: uid, custom_data: sessionId, transaction_id: transactionId } = event;
      if (!uid || uid.includes("/") || uid.length > 128 || !/^[a-f0-9-]{36}$/.test(sessionId || "") || !/^[a-zA-Z0-9_-]{1,256}$/.test(transactionId || "")) {
        throw new RewardsError(400, "Invalid reward event.");
      }
      const ref = account(uid);
      const receipt = database().collection("reward_receipts").doc(transactionId);
      const sessionRef = database().collection("reward_sessions").doc(sessionId);
      return database().runTransaction(async (tx) => {
        const existing = await tx.get(receipt);
        if (existing.exists) return; // Provider retries never pay twice.
        const wallet = (await tx.get(ref)).data() || {};
        const session = (await tx.get(sessionRef)).data();
        const eventTime = Number(event.timestamp);
        if (!session || session.uid !== uid || session.credited ||
            session.unitId.split("/").pop() !== String(event.ad_unit).split("/").pop() ||
            !Number.isFinite(eventTime) || eventTime < session.issuedAt - 60000 ||
            eventTime > session.expiresAt || eventTime > now() + 60000 ||
            now() - eventTime > 7 * 86400000 || Number(event.reward_amount) <= 0) {
          throw new RewardsError(400, "This reward session is not valid.");
        }
        tx.set(ref, { coins: (wallet.coins || 0) + COINS_PER_AD,
          ...(wallet.pendingSession?.id === sessionId ? { pendingSession: null } : {}) }, { merge: true });
        tx.set(sessionRef, { credited: true }, { merge: true });
        tx.set(receipt, { uid, sessionId, coins: COINS_PER_AD, receivedAt: now() });
      });
    },
    async redeem(uid, offerId, requestId) {
      const offer = OFFERS.find((entry) => entry.id === offerId);
      if (!offer || !/^[a-zA-Z0-9_-]{16,100}$/.test(requestId || "")) {
        throw new RewardsError(400, "Choose a valid ad-free pass.");
      }
      const ref = account(uid);
      const receipt = ref.collection("redemptions").doc(requestId);
      await database().runTransaction(async (tx) => {
        const prior = await tx.get(receipt);
        if (prior.exists) return; // Retrying an uncertain HTTP result is safe.
        const wallet = (await tx.get(ref)).data() || {};
        if ((wallet.coins || 0) < offer.coins) throw new RewardsError(409, "You do not have enough coins for this pass yet.");
        const until = Math.max(now(), wallet.adFreeUntil || 0) + offer.hours * 3600000;
        tx.set(ref, { coins: wallet.coins - offer.coins, adFreeUntil: until }, { merge: true });
        tx.set(receipt, { offerId, coins: offer.coins, adFreeUntil: until, redeemedAt: now() });
      });
      return publicWallet((await ref.get()).data());
    },
  };
}

function registerRewardsRoutes(app, { authenticate, firebaseApp }) {
  const rewards = createRewards({
    db: () => getFirestore(firebaseApp()),
    enabled: () => process.env.ADMOB_REWARDS_ENABLED === "true",
    units: () => (process.env.ADMOB_REWARDED_UNIT_IDS || "").split(",").map((s) => s.trim()).filter(Boolean),
  });
  const verify = createSsvVerifier();
  const route = (action) => async (req, res) => {
    res.set("Cache-Control", "no-store");
    try { return res.json(await action(req)); }
    catch (error) {
      return res.status(error instanceof RewardsError ? error.status : 503).json({
        error: error instanceof RewardsError ? error.message : "Cinema Rewards is temporarily unavailable. Please try again.",
      });
    }
  };
  const member = (req, res, next) => {
    if (req.firebaseUser.firebase?.sign_in_provider === "anonymous") {
      return res.status(403).json({ error: "Sign in with your account to use Cinema Rewards." });
    }
    next();
  };
  app.get("/api/rewards/wallet", authenticate, member, route((req) => rewards.wallet(req.firebaseUser.uid)));
  app.post("/api/rewards/session", authenticate, member, route((req) => rewards.session(req.firebaseUser.uid, req.body?.unitId)));
  app.post("/api/rewards/cancel", authenticate, member, route((req) => rewards.cancel(req.firebaseUser.uid, req.body?.sessionId)));
  app.post("/api/rewards/redeem", authenticate, member, route((req) => rewards.redeem(req.firebaseUser.uid, req.body?.offerId, req.body?.requestId)));
  app.get("/api/rewards/ssv", route(async (req) => {
    await rewards.credit(await verify(req.originalUrl));
    return { received: true };
  }));
}

module.exports = { createRewards, createSsvVerifier, registerRewardsRoutes, RewardsError, OFFERS };
