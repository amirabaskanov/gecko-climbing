#!/usr/bin/env node
// One-time maintenance: recount followersCount / followingCount from the
// actual follow-edge subcollections. Run once after deploying the
// onFollowChanged triggers to correct any historical drift (the old client
// reconcile path raced follow writes and could clobber counts).
//
// Usage (needs owner credentials):
//   cd functions
//   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> node scripts/recountFollows.js
// or, with gcloud auth application-default login already done:
//   node scripts/recountFollows.js
//
// Safe to re-run; it writes absolute values while no follows are in flight.

const admin = require('firebase-admin');

admin.initializeApp({ projectId: 'gecko-climbing' });
const db = admin.firestore();

async function main() {
  const users = await db.collection('users').get();
  console.log(`Recounting follows for ${users.size} users…`);
  let fixed = 0;

  for (const doc of users.docs) {
    const [followers, following] = await Promise.all([
      doc.ref.collection('followers').count().get(),
      doc.ref.collection('following').count().get(),
    ]);
    const actualFollowers = followers.data().count;
    const actualFollowing = following.data().count;
    const { followersCount = 0, followingCount = 0 } = doc.data();

    if (followersCount !== actualFollowers || followingCount !== actualFollowing) {
      await doc.ref.update({
        followersCount: actualFollowers,
        followingCount: actualFollowing,
      });
      fixed += 1;
      console.log(
        `  ${doc.id}: followers ${followersCount}→${actualFollowers}, following ${followingCount}→${actualFollowing}`
      );
    }
  }

  console.log(`Done. ${fixed} user(s) corrected.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
