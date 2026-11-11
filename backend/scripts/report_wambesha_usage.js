const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });
const { database } = require('../neon_database');
const { createWambeshaBudget } = require('../wambesha_budget');

(async () => {
  try {
    console.log(JSON.stringify(await createWambeshaBudget({ database }).report(), null, 2));
  } catch (_) {
    console.error('Could not read Wambesha usage. Check database access and budget settings.');
    process.exitCode = 1;
  }
})();
