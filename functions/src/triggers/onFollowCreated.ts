// S1 — fires when a follower doc is created, notifies the followed user.
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { sendNotification } from '../helpers/fcm';
import { lookupDisplayName } from '../helpers/users';

export const onFollowCreated = onDocumentCreated(
  {
    document: 'users/{uid}/followers/{followerUid}',
    region: 'us-central1',
  },
  async (event) => {
    if (!event.data) {
      logger.info('onFollowCreated: no event data, skipping');
      return;
    }
    const uid = event.params.uid;
    const followerUid = event.params.followerUid;

    if (uid === followerUid) {
      logger.info('onFollowCreated: self-follow, skipping', { uid });
      return;
    }

    const actorName = await lookupDisplayName(followerUid);
    logger.info('onFollowCreated: dispatching', { uid, followerUid, actorName });

    await sendNotification({
      recipientUid: uid,
      actorUid: followerUid,
      category: 'social',
      title: `${actorName} started following you`,
      body: '',
      route: { kind: 'profile', userId: followerUid },
    });
  }
);
