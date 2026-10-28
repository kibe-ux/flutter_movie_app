const serverless = require("serverless-http");

const MAX_BODY_BYTES = 1024 * 1024;

async function requestBody(request) {
  if (!request.body) return Buffer.alloc(0);
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BODY_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(Buffer.from(value));
    }
    return Buffer.concat(chunks, size);
  } finally {
    reader.releaseLock();
  }
}

function createNeonHandler(app) {
  const handle = serverless(app, { binary: ["*/*"] });
  return {
    async fetch(request) {
      const url = new URL(request.url);
      const body = await requestBody(request);
      if (body === null) {
        return Response.json({ error: "Request body is too large." }, { status: 413 });
      }
      const headers = Object.fromEntries(request.headers);
      headers.host = url.host;
      headers["content-length"] = String(body.length);
      headers["x-forwarded-proto"] = "https";
      const event = {
        version: "2.0",
        routeKey: "$default",
        rawPath: url.pathname,
        rawQueryString: url.search.slice(1),
        headers,
        body: body.toString("base64"),
        isBase64Encoded: true,
        requestContext: {
          domainName: url.host,
          http: {
            method: request.method,
            path: url.pathname,
            protocol: "HTTP/1.1",
            sourceIp: "127.0.0.1",
            userAgent: headers["user-agent"] || "",
          },
        },
      };
      const result = await handle(event, {});
      const responseHeaders = new Headers(result.headers);
      for (const cookie of result.cookies || []) responseHeaders.append("set-cookie", cookie);
      if (url.pathname.startsWith("/api/")) responseHeaders.set("cache-control", "no-store");
      const hasBody = request.method !== "HEAD" && ![204, 205, 304].includes(result.statusCode);
      return new Response(hasBody
        ? Buffer.from(result.body || "", result.isBase64Encoded ? "base64" : "utf8")
        : null, { status: result.statusCode, headers: responseHeaders });
    },
  };
}

module.exports = { createNeonHandler };
