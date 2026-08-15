// Maintains followersCount / followingCount server-side. Clients write only
// the two follow-edge documents (users/{uid}/followers/{followerUid} and the
// mirrored following doc); these triggers own the counters, so counts can't
// be spoofed by clients and a follow can't fail on a missing target user doc.
import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { db } from '../admin';

async function bumpIfExists(path: string, field: string, delta: number): Promise<void> {
  // Transaction, not a blind increment: account deletion removes the user doc
  // before its follow edges cascade-delete, so an unconditional set(merge)
  // here would resurrect ghost user docs containing only a counter field.
  // Skipping missing docs also avoids NOT_FOUND on dangling edges. Counts are
  // clamped at zero so replayed/duplicate deletes can't go negative.
  await db.runTransaction(async (tx) => {
    const ref = db.doc(path);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      return;
    }
    const current = (snap.get(field) as number | undefined) ?? 0;
    tx.update(ref, { [field]: Math.max(0, current + delta) });
  });
}

async function applyCountDelta(uid: string, followerUid: string, delta: number): Promise<void> {
  const results = await Promise.allSettled([
    bumpIfExists(`users/${uid}`, 'followersCount', delta),
    bumpIfExists(`users/${followerUid}`, 'followingCount', delta),
  ]);
  for (const result of results) {
    if (result.status === 'rejected') {
      logger.error('onFollowChanged: counter write failed', { uid, followerUid, delta, reason: `${result.reason}` });
    }
  }
}

export const onFollowerCreated = onDocumentCreated(
  {
    document: 'users/{uid}/followers/{followerUid}',
    region: 'us-central1',
  },
  async (event) => {
    const { uid, followerUid } = event.params;
    if (uid === followerUid) {
      logger.info('onFollowerCreated: self-follow, skipping', { uid });
      return;
    }
    await applyCountDelta(uid, followerUid, 1);
  }
);

export const onFollowerDeleted = onDocumentDeleted(
  {
    document: 'users/{uid}/followers/{followerUid}',
    region: 'us-central1',
  },
  async (event) => {
    const { uid, followerUid } = event.params;
    if (uid === followerUid) {
      return;
    }
    await applyCountDelta(uid, followerUid, -1);
  }
);
