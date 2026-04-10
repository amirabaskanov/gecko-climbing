// S2 — appends a like into a 30-minute batch; the sweeper flushes it later.
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { db } from '../admin';
import { appendToBatch } from '../helpers/batch';
import { lookupDisplayName } from '../helpers/users';

const LIKE_WINDOW_MS = 30 * 60 * 1000;

export const onLikeCreated = onDocumentCreated(
  {
    document: 'posts/{postId}/likes/{userId}',
    region: 'us-central1',
  },
  async (event) => {
    if (!event.data) {
      logger.info('onLikeCreated: no event data, skipping');
      return;
    }
    const postId = event.params.postId;
    const actorUid = event.params.userId;

    const postSnap = await db.collection('posts').doc(postId).get();
    if (!postSnap.exists) {
      logger.info('onLikeCreated: post missing, skipping', { postId });
      return;
    }
    const postOwnerUidRaw = postSnap.data()?.userId;
    const postOwnerUid = typeof postOwnerUidRaw === 'string' ? postOwnerUidRaw : '';
    if (postOwnerUid.length === 0) {
      logger.info('onLikeCreated: post has no owner, skipping', { postId });
      return;
    }

    if (actorUid === postOwnerUid) {
      logger.info('onLikeCreated: self-like, skipping', { postId, actorUid });
      return;
    }

    const actorDisplayName = await lookupDisplayName(actorUid);
    logger.info('onLikeCreated: appending to batch', { postId, actorUid, postOwnerUid });

    await appendToBatch(
      `like:${postId}`,
      {
        actorUid,
        actorDisplayName,
        createdAtMs: Date.now(),
      },
      LIKE_WINDOW_MS,
      {
        recipientUid: postOwnerUid,
        category: 'social',
        kind: 'like',
        postId,
      }
    );
  }
);
