import { defineConfig } from "@neon/config/v1";
import config from "./neon";

// Deploy the public movie API without changing cleanup jobs or their schedule.
export default defineConfig({
  functions: config.functions ? { moviehub: config.functions.moviehub } : {},
});
