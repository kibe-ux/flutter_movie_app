const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { build } = require("esbuild");
const dotenv = require("dotenv");

const backend = path.resolve(__dirname, "..");
const settings = dotenv.parse(fs.readFileSync(path.join(backend, ".env")));
const deploymentEnvironment = { ...settings, ...process.env };
const privateValues = Object.entries(deploymentEnvironment)
  .filter(([name]) => /SECRET|TOKEN|PASSWORD|API_KEY|DATABASE_URL|SERVICE_ACCOUNT_JSON/.test(name))
  .map(([, value]) => value).filter(Boolean);
if (deploymentEnvironment.FIREBASE_SERVICE_ACCOUNT_JSON) {
  try {
    const key = JSON.parse(deploymentEnvironment.FIREBASE_SERVICE_ACCOUNT_JSON).private_key;
    if (key) privateValues.push(key, JSON.stringify(key).slice(1, -1));
  } catch (_) { throw new Error('Invalid Firebase runtime credential JSON.'); }
}
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
    env: deploymentEnvironment,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    throw new Error(safeOutput(result.stderr || result.stdout) || "Neon command failed.");
  }
  if (json) return JSON.parse(result.stdout);
  console.log(safeOutput(result.stdout));
}

async function bundle() {
  for (const [entry, output] of [["moviehub", "index.mjs"], ["accountcleanup", "accountcleanup/index.mjs"]]) {
  const outputPath = path.join(backend, ".neon-build", output);
  await build({
    entryPoints: [path.join(backend, "functions", entry, "index.mjs")],
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
  console.log(`${entry} bundle ready (${bytes.length} bytes); private settings excluded.`);
  }
}

async function main() {
  const mode = process.argv[2] || "--plan";
  const catalogueOnly = process.argv.includes("--catalogue-only");
  const configFile = catalogueOnly ? "neon.catalogue.ts" : "neon.ts";
  if (!["--build", "--plan", "--deploy", "--status"].includes(mode)) throw new Error("Unknown deployment mode.");
  if (mode !== "--status") await bundle();
  if (mode === "--build") return;
  const target = ["--project-id", projectId, "--branch", branchId];
  if (mode === "--plan") {
    const plan = runNeon(["config", "plan", "--config", configFile, "--env", ".env", ...target, "-o", "json"], { json: true });
    if (plan.projectId !== projectId || plan.branchId !== branchId || !plan.dryRun) throw new Error('Unexpected plan target.');
    const changes = plan.applied.filter(change => change.action !== 'noop');
    console.log(JSON.stringify({ projectId, branchId, dryRun: true,
      changes: changes.map(({ kind, action, identifier }) => ({ kind, action, identifier })),
      conflicts: plan.conflicts.length }, null, 2));
    const allowed = new Set(catalogueOnly ? ['function:moviehub'] : ['function:moviehub', 'function:accountcleanup', 'trigger:accountcleanup:account-deletion-retries']);
    if (plan.conflicts.length || changes.some(change => change.action === 'delete' || change.kind === 'branch' || !allowed.has(change.identifier))) {
      throw new Error('Deployment plan includes a conflict or unrelated branch/deletion change.');
    }
    return;
  }
  if (mode === "--deploy") {
    const applied = runNeon(["deploy", "--config", configFile, "--env", ".env", "--no-env-pull", ...target, "-o", "json"], { json: true });
    console.log(JSON.stringify({ deployed: true, changes: (applied.applied || []).filter(change => change.action !== 'noop')
      .map(({ kind, action, identifier }) => ({ kind, action, identifier })) }));
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
