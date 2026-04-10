// Scheduled sweeper — flushes expired notificationBatches docs and dispatches their coalesced notifications.
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { db } from '../admin';
import { BatchDoc, deleteBatch, listExpiredBatches } from '../helpers/batch';
import { sendNotification } from '../helpers/fcm';

async function flushLikeBatch(id: string, doc: BatchDoc): Promise<void> {
  const postId = doc.postId;
  if (!postId) {
    logger.warn('batchSweeper: like batch missing postId, deleting', { id });
    await deleteBatch(id);
    return;
  }
  const entries = Array.isArray(doc.entries) ? doc.entries : [];
  if (entries.length === 0) {
    logger.info('batchSweeper: empty like batch, deleting', { id });
    await deleteBatch(id);
    return;
  }

  const postSnap = await db.collection('posts').doc(postId).get();
  const topGradeRaw = postSnap.exists ? postSnap.data()?.topGrade : undefined;
  const topGrade = typeof topGradeRaw === 'string' && topGradeRaw.length > 0 ? topGradeRaw : undefined;
  const subject = topGrade ?? 'climb';

  const firstActorName = entries[0].actorDisplayName;
  const otherCount = entries.length - 1;
  const title =
    otherCount === 0
      ? `${firstActorName} liked your ${subject} post`
      : `${firstActorName} and ${otherCount} other${otherCount === 1 ? '' : 's'} liked your ${subject} post`;

  logger.info('batchSweeper: flushing like batch', {
    id,
    postId,
    count: entries.length,
    recipientUid: doc.recipientUid,
  });

  await sendNotification({
    recipientUid: doc.recipientUid,
    actorUid: entries[0].actorUid,
    category: doc.category,
    title,
    body: '',
    route: { kind: 'post', id: postId },
  });

  await deleteBatch(id);
}

export const flushNotificationBatches = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'UTC',
    region: 'us-central1',
  },
  async () => {
    const now = Date.now();
    const expired = await listExpiredBatches(now);
    logger.info('batchSweeper: sweep start', { expiredCount: expired.length });

    for (const { id, doc } of expired) {
      try {
        switch (doc.kind) {
          case 'like':
            await flushLikeBatch(id, doc);
            break;
          default:
            logger.warn('batchSweeper: unknown kind, deleting', { id, kind: doc.kind });
            await deleteBatch(id);
        }
      } catch (err) {
        logger.error('batchSweeper: flush failed', { id, err });
      }
    }

    logger.info('batchSweeper: sweep done');
  }
);
