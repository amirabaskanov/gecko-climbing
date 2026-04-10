// S3/S4/S5 — single comment-created handler that dispatches post-owner, mention, and reply notifications.
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { db } from '../admin';
import { sendNotification } from '../helpers/fcm';
import { lookupDisplayName } from '../helpers/users';

const MAX_BODY_CHARS = 120;

interface CommentData {
  userId: string;
  text: string;
  parentId?: string;
  mentions: string[];
}

function truncate(input: string, max: number): string {
  if (input.length <= max) {
    return input;
  }
  return `${input.slice(0, max - 1)}…`;
}

function parseComment(raw: unknown): CommentData | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const obj = raw as Record<string, unknown>;
  const userId = typeof obj.userId === 'string' ? obj.userId : '';
  if (userId.length === 0) {
    return null;
  }
  const text = typeof obj.text === 'string' ? obj.text : '';
  const parentId = typeof obj.parentId === 'string' && obj.parentId.length > 0 ? obj.parentId : undefined;
  const mentionsRaw = obj.mentions;
  const mentions: string[] = Array.isArray(mentionsRaw)
    ? mentionsRaw.filter((m): m is string => typeof m === 'string' && m.length > 0)
    : [];
  return { userId, text, parentId, mentions };
}

export const onCommentCreated = onDocumentCreated(
  {
    document: 'posts/{postId}/comments/{commentId}',
    region: 'us-central1',
  },
  async (event) => {
    if (!event.data) {
      logger.info('onCommentCreated: no event data, skipping');
      return;
    }
    const postId = event.params.postId;
    const commentId = event.params.commentId;

    const comment = parseComment(event.data.data());
    if (!comment) {
      logger.info('onCommentCreated: malformed comment, skipping', { postId, commentId });
      return;
    }

    const postSnap = await db.collection('posts').doc(postId).get();
    if (!postSnap.exists) {
      logger.info('onCommentCreated: post missing, skipping', { postId, commentId });
      return;
    }
    const postOwnerUidRaw = postSnap.data()?.userId;
    const postOwnerUid = typeof postOwnerUidRaw === 'string' ? postOwnerUidRaw : '';
    if (postOwnerUid.length === 0) {
      logger.info('onCommentCreated: post has no owner, skipping', { postId, commentId });
      return;
    }

    const actorName = await lookupDisplayName(comment.userId);
    const truncatedBody = truncate(comment.text, MAX_BODY_CHARS);
    const mentionsSet = new Set(comment.mentions);

    if (comment.parentId) {
      const parentSnap = await db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(comment.parentId)
        .get();
      if (parentSnap.exists) {
        const parentUserIdRaw = parentSnap.data()?.userId;
        const parentUserId = typeof parentUserIdRaw === 'string' ? parentUserIdRaw : '';
        if (parentUserId.length > 0 && parentUserId !== comment.userId && !mentionsSet.has(parentUserId)) {
          logger.info('onCommentCreated: S5 reply dispatch', { postId, commentId, parentUserId });
          await sendNotification({
            recipientUid: parentUserId,
            actorUid: comment.userId,
            category: 'social',
            title: `${actorName} replied to your comment`,
            body: truncatedBody,
            route: { kind: 'comment', postId, commentId },
          });
        } else {
          logger.info('onCommentCreated: S5 suppressed', {
            postId,
            commentId,
            selfReply: parentUserId === comment.userId,
            mentioned: mentionsSet.has(parentUserId),
          });
        }
      } else {
        logger.info('onCommentCreated: parent comment missing, skipping S5', {
          postId,
          parentId: comment.parentId,
        });
      }
    } else {
      const ownerIsAuthor = postOwnerUid === comment.userId;
      const ownerAlreadyMentioned = mentionsSet.has(postOwnerUid);
      if (!ownerIsAuthor && !ownerAlreadyMentioned) {
        logger.info('onCommentCreated: S3 owner dispatch', { postId, commentId, postOwnerUid });
        await sendNotification({
          recipientUid: postOwnerUid,
          actorUid: comment.userId,
          category: 'social',
          title: `${actorName} commented`,
          body: truncatedBody,
          route: { kind: 'comment', postId, commentId },
        });
      } else {
        logger.info('onCommentCreated: S3 suppressed', {
          postId,
          commentId,
          ownerIsAuthor,
          ownerAlreadyMentioned,
        });
      }
    }

    for (const mentionedUid of mentionsSet) {
      if (mentionedUid === comment.userId) {
        continue;
      }
      logger.info('onCommentCreated: S4 mention dispatch', { postId, commentId, mentionedUid });
      await sendNotification({
        recipientUid: mentionedUid,
        actorUid: comment.userId,
        category: 'social',
        title: `${actorName} mentioned you`,
        body: truncatedBody,
        route: { kind: 'comment', postId, commentId },
        bypassQuietHours: true,
      });
    }
  }
);
