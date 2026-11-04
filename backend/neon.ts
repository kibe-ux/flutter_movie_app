import { defineConfig } from "@neon/config/v1";

const wambeshaApiKey = process.env.WAMBESHA_API_KEY?.trim();
const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
const tmdbApiKey = process.env.TMDB_API_KEY?.trim();
const adminCredentials = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
const workerEnabled = process.env.ACCOUNT_DELETION_WORKER_ENABLED === "true";
if (!wambeshaApiKey || !projectId || !tmdbApiKey) {
  throw new Error("Set TMDB_API_KEY, WAMBESHA_API_KEY and FIREBASE_PROJECT_ID in backend/.env before deploying.");
}

export default defineConfig({
  functions: {
    moviehub: {
      name: "Movie Hub download API",
      source: "./.neon-build/index.mjs",
      bundler: "none",
      env: {
        TMDB_API_KEY: tmdbApiKey,
        CATALOGUE_CLIENT_LIMIT: process.env.CATALOGUE_CLIENT_LIMIT || "120",
        CATALOGUE_UPSTREAM_LIMIT: process.env.CATALOGUE_UPSTREAM_LIMIT || "600",
        WAMBESHA_API_KEY: wambeshaApiKey,
        FIREBASE_PROJECT_ID: projectId,
        ...(adminCredentials ? { FIREBASE_SERVICE_ACCOUNT_JSON: adminCredentials } : {}),
        NODE_ENV: "production",
        ACCOUNT_DELETION_ENABLED: process.env.ACCOUNT_DELETION_ENABLED === "true" ? "true" : "false",
        ADMOB_REWARDS_ENABLED: process.env.ADMOB_REWARDS_ENABLED === "true" ? "true" : "false",
        ADMOB_REWARDED_UNIT_IDS: process.env.ADMOB_REWARDED_UNIT_IDS?.trim() || "",
        ...(process.env.JWT_SECRET ? { JWT_SECRET: process.env.JWT_SECRET } : {}),
      },
    },
    accountcleanup: {
      name: "Movie Hub account deletion retries",
      source: "./.neon-build/accountcleanup/index.mjs",
      bundler: "none",
      env: {
        FIREBASE_PROJECT_ID: projectId,
        NODE_ENV: "production",
        ACCOUNT_DELETION_WORKER_ENABLED: workerEnabled ? "true" : "false",
        ...(adminCredentials ? { FIREBASE_SERVICE_ACCOUNT_JSON: adminCredentials } : {}),
      },
    },
  },
  triggers: {
    "account-deletion-retries": {
      type: "schedule",
      function: "accountcleanup",
      cron: "*/5 * * * *",
      enabled: workerEnabled,
    },
  },
});
