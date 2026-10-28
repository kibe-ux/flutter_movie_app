const assert = require("node:assert/strict");
const test = require("node:test");
const app = require("../server");

test("FILMS365 proxy rejects requests without a Firebase ID token", async (t) => {
  const server = app.listen(0);
  t.after(
    () =>
      new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      })
  );

  const address = server.address();
  const response = await fetch(
    `http://127.0.0.1:${address.port}/api/mobile/trending`
  );

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    error: "A Firebase ID token is required.",
  });
});

test("all FILMS365 proxy routes require a Firebase ID token", async (t) => {
  const server = app.listen(0);
  t.after(
    () =>
      new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      })
  );

  const address = server.address();
  const routes = [
    ["/api/mobile/trending", "GET"],
    ["/api/mobile/details/torrent-link", "POST"],
    ["/api/mobile/popular", "GET"],
    ["/api/mobile/latest", "GET"],
    ["/api/mobile/explore", "GET"],
    ["/api/mobile/details?type=movie&id=example", "GET"],
    ["/api/mobile/search", "POST"],
    ["/api/mobile/person?type=movie&tmdbId=1", "GET"],
    ["/api/mobile/details/torrent-link", "POST"],
  ];

  for (const [path, method] of routes) {
    const response = await fetch(`http://127.0.0.1:${address.port}${path}`, {
      method,
    });
    assert.equal(response.status, 401, `${method} ${path}`);
  }
});

test("proxy sends the server-side ApiKey header and forwards query parameters",
    async (t) => {
      const previousApiKey = process.env.FILMS365_API_KEY;
      process.env.FILMS365_API_KEY = "test-only-films365-key";
      t.after(() => {
        if (previousApiKey === undefined) {
          delete process.env.FILMS365_API_KEY;
        } else {
          process.env.FILMS365_API_KEY = previousApiKey;
        }
      });

      let upstreamUrl;
      let upstreamOptions;
      t.mock.method(global, "fetch", async (url, options) => {
        upstreamUrl = new URL(url);
        upstreamOptions = options;
        return new Response('{"status":"ok"}', {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      });

      const response = createMockResponse();
      await app.locals.proxyFilms365Request(
        {
          method: "GET",
          originalUrl: "/api/mobile/explore?type=tv&page=2&genre=Sci-Fi",
          params: { endpoint: "explore" },
          header: () => undefined,
        },
        response
      );

      assert.equal(upstreamUrl.pathname, "/api/mobile/explore");
      assert.deepEqual(Object.fromEntries(upstreamUrl.searchParams), {
        type: "tv",
        page: "2",
        genre: "Sci-Fi",
      });
      assert.equal(upstreamOptions.method, "GET");
      assert.equal(
        upstreamOptions.headers.Authorization,
        "ApiKey test-only-films365-key"
      );
      assert.equal(response.statusCode, 200);
      assert.equal(response.body.toString(), '{"status":"ok"}');
    });

test("proxy forwards the search JSON body without logging it", async (t) => {
  const previousApiKey = process.env.FILMS365_API_KEY;
  process.env.FILMS365_API_KEY = "test-only-films365-key";
  t.after(() => {
    if (previousApiKey === undefined) {
      delete process.env.FILMS365_API_KEY;
    } else {
      process.env.FILMS365_API_KEY = previousApiKey;
    }
  });

  let upstreamOptions;
  t.mock.method(global, "fetch", async (_url, options) => {
    upstreamOptions = options;
    return new Response('{"results":{"all":[]}}', {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  });

  const response = createMockResponse();
  await app.locals.proxyFilms365Request(
    {
      method: "POST",
      originalUrl: "/api/mobile/search",
      params: { endpoint: "search" },
      header: (name) =>
        name === "content-type" ? "application/json" : undefined,
      body: Buffer.from('{"query":"Dune"}'),
    },
    response
  );

  assert.equal(upstreamOptions.method, "POST");
  assert.equal(upstreamOptions.headers["Content-Type"], "application/json");
  assert.equal(upstreamOptions.body.toString(), '{"query":"Dune"}');
  assert.equal(response.statusCode, 200);
});

test("proxy preserves upstream errors and safely handles upstream failures",
    async (t) => {
      const previousApiKey = process.env.FILMS365_API_KEY;
      process.env.FILMS365_API_KEY = "test-only-films365-key";
      t.after(() => {
        if (previousApiKey === undefined) {
          delete process.env.FILMS365_API_KEY;
        } else {
          process.env.FILMS365_API_KEY = previousApiKey;
        }
      });

      let fetchImplementation = async () =>
        new Response('{"error":"upstream rejected request"}', {
          status: 429,
          headers: { "content-type": "application/json" },
        });
      t.mock.method(global, "fetch", (...args) =>
        fetchImplementation(...args)
      );
      const logged = [];
      t.mock.method(console, "error", (...args) => logged.push(args.join(" ")));

      const rejectedResponse = createMockResponse();
      await app.locals.proxyFilms365Request(
        {
          method: "GET",
          originalUrl: "/api/mobile/trending",
          params: { endpoint: "trending" },
          header: () => undefined,
        },
        rejectedResponse
      );
      assert.equal(rejectedResponse.statusCode, 429);
      assert.equal(
        Object.keys(rejectedResponse.headers).includes("Authorization"),
        false
      );
      assert.equal(logged.length, 1);
      assert.match(logged[0], /^UPSTREAM_FAIL /);

      fetchImplementation = async () => {
        throw Object.assign(new Error("connection failed"), {
          name: "FetchError",
        });
      };
      const failedResponse = createMockResponse();
      await app.locals.proxyFilms365Request(
        {
          method: "GET",
          originalUrl: "/api/mobile/trending",
          params: { endpoint: "trending" },
          header: () => undefined,
        },
        failedResponse
      );
      assert.equal(failedResponse.statusCode, 502);
      assert.deepEqual(failedResponse.body, {
        error: "FILMS365 is unavailable.",
      });
      assert.equal(logged.join(" ").includes("test-only-films365-key"), false);

      fetchImplementation = async () => {
        throw Object.assign(new Error("timeout"), { name: "TimeoutError" });
      };
      const timeoutResponse = createMockResponse();
      await app.locals.proxyFilms365Request(
        {
          method: "GET",
          originalUrl: "/api/mobile/trending",
          params: { endpoint: "trending" },
          header: () => undefined,
        },
        timeoutResponse
      );
      assert.equal(timeoutResponse.statusCode, 504);
      assert.deepEqual(timeoutResponse.body, {
        error: "FILMS365 request timed out.",
      });
      assert.equal(logged.join(" ").includes("test-only-films365-key"), false);
    });

test("movie catalogue and download authorization require Firebase ID tokens", async (t) => {
  const server = app.listen(0);
  t.after(
    () =>
      new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      })
  );

  const address = server.address();
  for (const [path, method] of [
    ["/api/database/health", "GET"],
    ["/api/movies", "GET"],
    ["/api/download/request", "POST"],
  ]) {
    const response = await fetch(`http://127.0.0.1:${address.port}${path}`, {
      method,
    });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {
      error: "A Firebase ID token is required.",
    });
  }
});

test("upstream traces correlate failed and successful attempts without leaking secrets", async (t) => {
  const previousKey = process.env.FILMS365_API_KEY;
  process.env.FILMS365_API_KEY = "private-provider-credential";
  t.after(() => {
    if (previousKey === undefined) delete process.env.FILMS365_API_KEY;
    else process.env.FILMS365_API_KEY = previousKey;
  });
  const logs = [];
  t.mock.method(console, "log", (line) => logs.push(line));
  t.mock.method(console, "error", (line) => logs.push(line));
  let calls = 0;
  t.mock.method(global, "fetch", async () => {
    const status = ++calls === 1 ? 401 : 200;
    return new Response(JSON.stringify({
      error: "private-error-value", downloadUrl: "https://example.com/movie?token=private-link",
    }), { status, headers: {
      "cache-control": "private, max-age=60",
      "cf-cache-status": status === 401 ? "DYNAMIC" : "HIT",
      "age": status === 401 ? "0" : "12",
      "set-cookie": "private-cookie",
    } });
  });
  const responses = [];
  for (let attempt = 0; attempt < 2; attempt++) {
    const response = createMockResponse();
    responses.push(response);
    await app.locals.proxyFilms365Request({
      method: "GET", originalUrl: "/api/mobile/details?type=movie&id=movie-123&token=private-query",
      params: { endpoint: "details" }, header: () => undefined,
    }, response);
  }
  const traces = logs.map(line => JSON.parse(line.slice(line.indexOf(" ") + 1)));
  assert.equal(traces.length, 2);
  assert.deepEqual(traces.map(trace => trace.status), [401, 200]);
  assert.equal(traces[0].movieId, "movie-123");
  assert.equal(traces[0].backendInstance, traces[1].backendInstance);
  assert.equal(traces[0].credentialRevision, traces[1].credentialRevision);
  assert.notEqual(traces[0].requestId, traces[1].requestId);
  assert.equal(traces[0].requestId, responses[0].headers["X-MovieHub-Request-Id"]);
  assert.equal(traces[1].backendInstance, responses[1].headers["X-MovieHub-Backend-Instance"]);
  assert.ok(Number.isFinite(Date.parse(traces[0].timestamp)));
  assert.equal(traces[1].cache.cfCacheStatus, "HIT");
  assert.equal(traces[1].cache.age, 12);
  assert.equal(traces[1].cache.cacheControl, "private, max-age=60");
  assert.equal(calls, 2); // One upstream request per manual attempt; no 401 retry.
  for (const secret of ["private-provider-credential", "private-error-value", "private-link", "private-cookie", "private-query", "https://"]) {
    assert.equal(logs.join(" ").includes(secret), false);
  }
  assert.match(responses[1].body.toString(), /private-link/); // Body still reaches caller unchanged.
});

test("proxy keeps endpoint and method validation ahead of upstream requests", async (t) => {
  let calls = 0;
  t.mock.method(global, "fetch", async () => { calls++; });
  for (const [endpoint, method, status, message, allow] of [
    ["unknown", "GET", 404, "Unknown FILMS365 endpoint.", undefined],
    ["details", "POST", 405, "Method not allowed for this endpoint.", "GET"],
    ["details/torrent-link", "GET", 405, "Method not allowed for this endpoint.", "POST"],
  ]) {
    const response = createMockResponse();
    await app.locals.proxyFilms365Request({ method, params: { endpoint } }, response);
    assert.equal(response.statusCode, status);
    assert.deepEqual(response.body, { error: message });
    assert.equal(response.headers.Allow, allow);
  }
  assert.equal(calls, 0);
});

test("proxy preserves response bytes and content type without logging the body", async (t) => {
  const previousKey = process.env.FILMS365_API_KEY;
  process.env.FILMS365_API_KEY = "test-only-films365-key";
  t.after(() => {
    if (previousKey === undefined) delete process.env.FILMS365_API_KEY;
    else process.env.FILMS365_API_KEY = previousKey;
  });
  const body = Buffer.from([0x00, 0xff, 0xfe, 0x7b, 0x7d]);
  t.mock.method(global, "fetch", async () => new Response(body, {
    status: 206, headers: { "content-type": "application/octet-stream" },
  }));
  const logs = [];
  t.mock.method(console, "log", (line) => logs.push(line));
  const response = createMockResponse();
  await app.locals.proxyFilms365Request({
    method: "GET", originalUrl: "/api/mobile/details?type=movie&id=example",
    params: { endpoint: "details" }, header: () => undefined,
  }, response);
  assert.equal(response.statusCode, 206);
  assert.deepEqual(response.body, body);
  assert.equal(response.headers["Content-Type"], "application/octet-stream");
  assert.equal(response.headers["X-MovieHub-Response-Source"], "films365");
  assert.equal(logs.length, 1);
  assert.match(logs[0], /^UPSTREAM_RESULT /);
});

test("request logs retain their existing endpoint classifications", async (t) => {
  const server = app.listen(0);
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  const logs = [];
  t.mock.method(console, "log", (line) => logs.push(line));
  t.mock.method(console, "warn", () => {});
  const origin = `http://127.0.0.1:${server.address().port}`;
  for (const [pathname, method, endpoint, status] of [
    ["/api/mobile/details?type=movie&tmdbId=42", "GET", "/api/mobile/details", 401],
    ["/api/mobile/details/torrent-link", "POST", "/api/mobile/details/torrent-link", 401],
    ["/api/movies", "GET", "/api/movies", 401],
    ["/api/movies/example", "GET", "/api/movies/:id", 401],
    ["/api/download/request", "POST", "/api/download/request", 401],
    ["/api/download/stream", "GET", "/api/download/stream", 400],
    ["/api/mobile/unknown", "GET", "/api/other", 401],
    ["/api/unknown", "GET", "/api/other", 404],
  ]) {
    const response = await fetch(origin + pathname, { method });
    await response.arrayBuffer();
    assert.equal(response.status, status);
    const trace = JSON.parse(logs.at(-1));
    assert.equal(trace.endpoint, endpoint);
    assert.equal(trace.status, status);
    assert.ok(trace.requestId);
  }
});

function createMockResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: undefined,
    set(name, value) {
      this.headers[name] = value;
      return this;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}
