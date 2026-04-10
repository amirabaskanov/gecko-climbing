// F2 — fans out a friend-posted notification to followers who have opted in to friendPosts.
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { sendNotification } from '../helpers/fcm';
import { lookupDisplayName } from '../helpers/users';
import { paginateFollowers, friendPostsOptedIn } from '../helpers/followers';

const MAX_BODY_CHARS = 120;
const PREF_CHECK_CONCURRENCY = 50;

interface PostShape {
  userId: string;
  caption: string;
  gymName: string;
}

function parsePost(raw: unknown): PostShape | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const obj = raw as Record<string, unknown>;
  const userId = typeof obj.userId === 'string' ? obj.userId : '';
  if (userId.length === 0) {
    return null;
  }
  const caption = typeof obj.caption === 'string' ? obj.caption : '';
  const gymName = typeof obj.gymName === 'string' ? obj.gymName : '';
  return { userId, caption, gymName };
}

function truncate(input: string, max: number): string {
  if (input.length <= max) {
    return input;
  }
  return `${input.slice(0, max - 1)}…`;
}

export const onPostCreated = onDocumentCreated(
  {
    document: 'posts/{postId}',
    region: 'us-central1',
  },
  async (event) => {
    if (!event.data) {
      logger.info('onPostCreated: no event data, skipping');
      return;
    }
    const postId = event.params.postId;
    const post = parsePost(event.data.data());
    if (!post) {
      logger.info('onPostCreated: malformed post, skipping', { postId });
      return;
    }

    const actorName = await lookupDisplayName(post.userId);
    const title = `${actorName} shared a session`;
    const bodySource = post.caption.length > 0 ? post.caption : post.gymName;
    const body = truncate(bodySource, MAX_BODY_CHARS);

    let totalFollowers = 0;
    let optedInCount = 0;
    for await (const page of paginateFollowers(post.userId)) {
      totalFollowers += page.length;
      for (let i = 0; i < page.length; i += PREF_CHECK_CONCURRENCY) {
        const slice = page.slice(i, i + PREF_CHECK_CONCURRENCY);
        const optIns = await Promise.all(slice.map((uid) => friendPostsOptedIn(uid)));
        const eligible: string[] = [];
        slice.forEach((uid, idx) => {
          if (optIns[idx]) {
            eligible.push(uid);
          }
        });
        optedInCount += eligible.length;
        await Promise.all(
          eligible.map((recipientUid) =>
            sendNotification({
              recipientUid,
              actorUid: post.userId,
              category: 'friends',
              title,
              body,
              route: { kind: 'post', id: postId },
            }).catch((err: unknown) => {
              logger.warn('onPostCreated: recipient send failed', {
                postId,
                recipientUid,
                err: err instanceof Error ? err.message : String(err),
              });
            })
          )
        );
      }
    }

    logger.info('onPostCreated: F2 fan-out complete', {
      postId,
      userId: post.userId,
      totalFollowers,
      optedInCount,
    });
  }
);
