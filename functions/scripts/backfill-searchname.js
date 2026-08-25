#!/usr/bin/env node
// One-time maintenance: write the derived `searchName` field (lowercased
// displayName) onto every user doc missing it. Docs written after the
// Discovery v2 client shipped get the field from UserDTO.asDictionary();
// this covers users created before that, so display-name search matches them.
//
// Usage (needs owner credentials):
//   cd functions
//   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> node scripts/backfill-searchname.js
// or, with gcloud auth application-default login already done:
//   node scripts/backfill-searchname.js
//
// Safe to re-run; it only touches docs whose searchName is missing or stale.

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'gecko-climbing' });
const db = admin.firestore();

async function main() {
  const users = await db.collection('users').get();
  console.log(`Checking searchName for ${users.size} users…`);
  let fixed = 0;

  for (const doc of users.docs) {
    const { displayName = '', searchName } = doc.data();
    if (!displayName) continue;
    const expected = displayName.toLowerCase();
    if (searchName === expected) continue;

    await doc.ref.update({ searchName: expected });
    fixed += 1;
    console.log(`  ${doc.id}: searchName "${searchName ?? '(missing)'}" → "${expected}"`);
  }

  console.log(`Done. ${fixed} user(s) updated.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
