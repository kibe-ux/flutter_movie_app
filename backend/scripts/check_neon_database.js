const path = require("node:path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env"), quiet: true });
const { database, NeonDatabaseError } = require("../neon_database");

async function main() {
  try {
    await database.checkConnection();
    console.log("Neon database connection OK.");
  } catch (error) {
    console.error(error instanceof NeonDatabaseError
      ? error.message : "Could not check the Neon database connection.");
    process.exitCode = 1;
  }
}

main();
