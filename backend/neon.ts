import { defineConfig } from "@neon/config/v1";

const apiKey = process.env.FILMS365_API_KEY?.trim();
const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
if (!apiKey || !projectId) {
  throw new Error("Set FILMS365_API_KEY and FIREBASE_PROJECT_ID in backend/.env before deploying.");
}

export default defineConfig({
  functions: {
    moviehub: {
      name: "Movie Hub download API",
      source: "./functions/moviehub/index.mjs",
      env: {
        FILMS365_API_KEY: apiKey,
        FIREBASE_PROJECT_ID: projectId,
        NODE_ENV: "production",
        ...(process.env.JWT_SECRET ? { JWT_SECRET: process.env.JWT_SECRET } : {}),
      },
    },
  },
});
