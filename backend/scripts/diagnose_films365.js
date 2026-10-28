const path = require("node:path");
require("dotenv").config({ path: path.join(__dirname, "../.env"), quiet: true });

// Report structure only: never print credentials, response values, or URLs.
function responseShape(value, depth = 0) {
  if (value === null) return "null";
  if (depth > 5) return Array.isArray(value) ? "array" : typeof value;
  if (Array.isArray(value)) {
    return { count: value.length, first: responseShape(value[0], depth + 1) };
  }
  if (typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) =>
      [key, responseShape(item, depth + 1)]));
  }
  if (typeof value === "string") {
    return { type: "string", empty: !value.trim(),
      httpUrl: /^https?:\/\//i.test(value), magnet: value.startsWith("magnet:") };
  }
  return typeof value;
}

async function main() {
  const key = process.env.FILMS365_API_KEY?.trim();
  if (!key) throw new Error("missing-configuration");
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 2 || args[0] !== "--id" || !args[1].trim())) {
    console.error("Usage: npm run diagnose:films365 -- [--id <provider-id>]");
    process.exitCode = 1;
    return;
  }

  async function request(endpoint, parameters) {
    const url = new URL(`/api/mobile/${endpoint}`, "https://www.films365.org");
    url.search = new URLSearchParams(parameters).toString();
    const response = await fetch(url, {
      headers: { Authorization: `ApiKey ${key}` },
      redirect: "error", signal: AbortSignal.timeout(15000),
    });
    const body = await response.json();
    console.log(JSON.stringify({ endpoint, status: response.status,
      shape: responseShape(body) }));
    if (!response.ok) {
      if (response.status === 401 || response.status === 403) {
        console.error(JSON.stringify({
          error: "provider-authorization-rejected",
          nextStep: "Compare this denied request with a successful attempt for the same movie. Confirm access with FILMS365 if rejections continue.",
        }));
      }
      process.exitCode = 1;
      return null;
    }
    return body;
  }

  let id = args[1];
  if (!id) {
    const catalogue = await request("popular", { type: "movie", page: "1" });
    if (!catalogue) return;
    const movie = catalogue.results?.find(item => item.type === "movie" && item.id);
    id = movie?.id;
    if (!id) throw new Error("no-provider-id");
  }
  await request("details", { type: "movie", id });
}

main().catch(error => {
  const safeCodes = new Set(["missing-configuration", "no-provider-id"]);
  console.error(JSON.stringify({ error: safeCodes.has(error.message)
    ? error.message : "diagnostic-request-failed" }));
  process.exitCode = 1;
});
