const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { getRuntimeFirebaseAuth } = require('../firebase_runtime');
const { getFirestore } = require('firebase-admin/firestore');
const { createAccountDeletion } = require('../account_deletion');

const auth = getRuntimeFirebaseAuth();
createAccountDeletion({ db: getFirestore(auth.app), auth }).retryPending()
  .then(() => console.log('Account deletion retry pass completed.'))
  .catch(() => { console.error('Account deletion retry pass failed; investigate and retry.'); process.exitCode = 1; });
