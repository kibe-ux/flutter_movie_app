const assert = require("node:assert/strict");
const test = require("node:test");
const express = require("express");
const app = require("../server");
const { createNeonHandler } = require("../neon_http");

test("the hosted API serves health and still requires Firebase authentication", async () => {
  const hosted = createNeonHandler(app);
  const health = await hosted.fetch(new Request("https://api.example/health"));
  assert.equal(health.status, 200);
  assert.equal((await health.json()).status, "ok");
  for (const route of ["/api/mobile/popular", "/api/database/health", "/api/movies"]) {
    const response = await hosted.fetch(new Request(`https://api.example${route}`));
    assert.equal(response.status, 401);
    assert.equal(response.headers.get("x-moviehub-response-source"), "firebase-auth");
    assert.equal(response.headers.get("cache-control"), "no-store");
  }
});

test("the hosted transport preserves POST bytes, query encoding and authorization", async () => {
  const fixture = express();
  fixture.use(express.raw({ type: "*/*" }));
  fixture.post("/api/mobile/search", (req, res) => res.json({
    originalUrl: req.originalUrl,
    body: req.body.toString("utf8"),
    authorization: req.get("authorization"),
    protocol: req.protocol,
  }));
  const body = '{ "query": "Cinema & café" }';
  const response = await createNeonHandler(fixture).fetch(new Request(
    "https://api.example/api/mobile/search?query=a%26b&type=movie", {
      method: "POST", body,
      headers: { "content-type": "application/json", authorization: "Bearer test-id-token" },
    }));
  assert.deepEqual(await response.json(), {
    originalUrl: "/api/mobile/search?query=a%26b&type=movie",
    body, authorization: "Bearer test-id-token", protocol: "https",
  });
});

test("binary response bytes and upstream status survive the hosted transport", async () => {
  const fixture = express();
  fixture.get("/binary", (_req, res) => res.status(206).type("application/octet-stream").send(Buffer.from([0, 128, 255])));
  const response = await createNeonHandler(fixture).fetch(new Request("https://api.example/binary"));
  assert.equal(response.status, 206);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), Buffer.from([0, 128, 255]));
});

test("oversized bodies are rejected before reaching the API", async () => {
  const fixture = express();
  fixture.post("/api/mobile/search", () => assert.fail("Oversized input reached the API"));
  const response = await createNeonHandler(fixture).fetch(new Request("https://api.example/api/mobile/search", {
    method: "POST", body: "a".repeat(1024 * 1024 + 1),
  }));
  assert.equal(response.status, 413);
});
