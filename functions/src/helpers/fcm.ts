// Central send pipeline — applies pref, quiet-hours, and rate-limit gates before dispatch to FCM.
import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions/v2';
import { db, messaging } from '../admin';
import { SendOptions, encodeRoute } from '../types';
import { isCategoryEnabled } from './prefs';
import { isInQuietHours } from './quietHours';
import { checkAndConsumeRateLimit } from './rateLimit';

export type SendResult =
  | 'sent'
  | 'skipped_self'
  | 'skipped_prefs'
  | 'skipped_quiet_hours'
  | 'skipped_rate_limit'
  | 'no_tokens'
  | 'failed';

const INVALID_TOKEN_ERRORS = new Set<string>([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export async function sendNotification(opts: SendOptions): Promise<SendResult> {
  const { recipientUid, actorUid, category, title, body, route } = opts;

  if (actorUid && actorUid === recipientUid) {
    logger.info('sendNotification: skipped_self', { recipientUid, category });
    return 'skipped_self';
  }

  if (!(await isCategoryEnabled(recipientUid, category))) {
    logger.info('sendNotification: skipped_prefs', { recipientUid, category });
    return 'skipped_prefs';
  }

  if (!opts.bypassQuietHours && (await isInQuietHours(recipientUid))) {
    logger.info('sendNotification: skipped_quiet_hours', { recipientUid, category });
    return 'skipped_quiet_hours';
  }

  if (!opts.bypassRateLimit && !(await checkAndConsumeRateLimit(recipientUid, category))) {
    logger.info('sendNotification: skipped_rate_limit', { recipientUid, category });
    return 'skipped_rate_limit';
  }

  const userRef = db.collection('users').doc(recipientUid);
  const userSnap = await userRef.get();
  const rawTokens = userSnap.exists ? userSnap.data()?.fcmTokens : undefined;
  const tokens: string[] = Array.isArray(rawTokens)
    ? (rawTokens.filter((t: unknown): t is string => typeof t === 'string' && t.length > 0) as string[])
    : [];

  if (tokens.length === 0) {
    logger.info('sendNotification: no_tokens', { recipientUid, category });
    return 'no_tokens';
  }

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      route: encodeRoute(route),
      category,
    },
  });

  const invalidTokens: string[] = [];
  response.responses.forEach((resp, idx) => {
    if (!resp.success && resp.error) {
      const code = resp.error.code;
      if (INVALID_TOKEN_ERRORS.has(code)) {
        invalidTokens.push(tokens[idx]);
      }
    }
  });

  if (invalidTokens.length > 0) {
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
    logger.info('sendNotification: pruned invalid tokens', {
      recipientUid,
      pruned: invalidTokens.length,
    });
  }

  if (response.successCount === 0) {
    logger.warn('sendNotification: failed', {
      recipientUid,
      category,
      failureCount: response.failureCount,
    });
    return 'failed';
  }

  logger.info('sendNotification: sent', {
    recipientUid,
    category,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });
  return 'sent';
}
