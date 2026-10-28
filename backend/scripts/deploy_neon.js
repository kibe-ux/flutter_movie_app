const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { build } = require("esbuild");
const dotenv = require("dotenv");

const backend = path.resolve(__dirname, "..");
const settings = dotenv.parse(fs.readFileSync(path.join(backend, ".env")));
const privateValues = [settings.FILMS365_API_KEY, settings.JWT_SECRET, settings.DATABASE_URL].filter(Boolean);
const cli = path.join(backend, "node_modules", "neon", "dist", "cli.js");
const projectId = "summer-shadow-58564268";
const branchId = "br-empty-forest-b4htkwt9";

function safeOutput(text) {
  let safe = text || "";
  for (const value of privateValues) safe = safe.split(value).join("[redacted]");
  return safe.split(/\r?\n/).filter((line) => !line.startsWith("DEBUG:")).join("\n").trim();
}

function runNeon(args, { json = false } = {}) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: backend, encoding: "utf8", windowsHide: true,
    env: { ...process.env, ...settings },
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    throw new Error(safeOutput(result.stderr || result.stdout) || "Neon command failed.");
  }
  if (json) return JSON.parse(result.stdout);
  console.log(safeOutput(result.stdout));
}

async function bundle() {
  const outputPath = path.join(backend, ".neon-build", "index.mjs");
  await build({
    entryPoints: [path.join(backend, "functions", "moviehub", "index.mjs")],
    outfile: outputPath,
    bundle: true, platform: "node", target: "node24", format: "esm",
    banner: { js: "import{createRequire as __makeRequire}from'node:module';import{fileURLToPath as __filePath}from'node:url';import{dirname as __dirPath}from'node:path';const require=__makeRequire(import.meta.url);const __filename=__filePath(import.meta.url);const __dirname=__dirPath(__filename);" },
  });
  const bytes = fs.readFileSync(outputPath);
  for (const value of privateValues) {
    if (value.length >= 8 && bytes.includes(Buffer.from(value))) {
      throw new Error("The bundle contains a private setting; deployment was stopped.");
    }
  }
  console.log(`Hosted API bundle ready (${bytes.length} bytes); private settings excluded.`);
}

async function main() {
  const mode = process.argv[2] || "--plan";
  if (!["--build", "--plan", "--deploy", "--status"].includes(mode)) throw new Error("Unknown deployment mode.");
  if (mode !== "--status") await bundle();
  if (mode === "--build") return;
  const target = ["--project-id", projectId, "--branch", branchId];
  if (mode === "--plan") {
    runNeon(["config", "plan", "--config", "neon.ts", "--env", ".env", ...target]);
    return;
  }
  if (mode === "--deploy") {
    runNeon(["deploy", "--config", "neon.ts", "--env", ".env", "--no-env-pull", ...target]);
  }
  const metadata = runNeon(["functions", "get", "moviehub", ...target, "-o", "json"], { json: true });
  const info = metadata.function || metadata;
  const deployment = info.active_deployment || info.current_deployment;
  console.log(JSON.stringify({
    invocation_url: info.invocation_url,
    deployment: deployment ? {
      id: deployment.id,
      status: deployment.status,
      runtime: deployment.runtime,
    } : null,
  }, null, 2));
}

main().catch((error) => {
  console.error(safeOutput(error.message));
  process.exitCode = 1;
});
