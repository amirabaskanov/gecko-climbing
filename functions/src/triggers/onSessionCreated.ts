// F1 — detects personal-best V-grade on new session and fans out to climber's followers.
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { db } from '../admin';
import { sendNotification } from '../helpers/fcm';
import { lookupDisplayName } from '../helpers/users';
import { paginateFollowers } from '../helpers/followers';

const MIN_GRADE_NUMERIC = 3;
const MIN_PRIOR_SESSIONS = 2;
const PREF_CHECK_CONCURRENCY = 50;

interface SessionShape {
  userId: string;
  highestGradeNumeric: number;
  highestGrade: string;
}

function parseSession(raw: unknown): SessionShape | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const obj = raw as Record<string, unknown>;
  const userId = typeof obj.userId === 'string' ? obj.userId : '';
  if (userId.length === 0) {
    return null;
  }
  const highestGradeNumeric =
    typeof obj.highestGradeNumeric === 'number' ? obj.highestGradeNumeric : Number.NaN;
  if (!Number.isFinite(highestGradeNumeric)) {
    return null;
  }
  const highestGrade = typeof obj.highestGrade === 'string' ? obj.highestGrade : '';
  return { userId, highestGradeNumeric, highestGrade };
}

export const onSessionCreated = onDocumentCreated(
  {
    document: 'sessions/{sessionId}',
    region: 'us-central1',
  },
  async (event) => {
    if (!event.data) {
      logger.info('onSessionCreated: no event data, skipping');
      return;
    }
    const sessionId = event.params.sessionId;
    const session = parseSession(event.data.data());
    if (!session) {
      logger.info('onSessionCreated: malformed session, skipping', { sessionId });
      return;
    }

    if (session.highestGradeNumeric < MIN_GRADE_NUMERIC) {
      logger.info('onSessionCreated: below grade floor, skipping', {
        sessionId,
        highestGradeNumeric: session.highestGradeNumeric,
      });
      return;
    }

    const priorCountSnap = await db
      .collection('sessions')
      .where('userId', '==', session.userId)
      .select()
      .limit(MIN_PRIOR_SESSIONS + 2)
      .get();
    const priorCount = priorCountSnap.docs.filter((d) => d.id !== sessionId).length;
    if (priorCount < MIN_PRIOR_SESSIONS) {
      logger.info('onSessionCreated: onboarding floor, skipping', {
        sessionId,
        userId: session.userId,
        priorCount,
      });
      return;
    }

    const userSnap = await db.collection('users').doc(session.userId).get();
    const prevMaxRaw = userSnap.exists ? userSnap.data()?.highestGradeNumeric : undefined;
    const prevMax = typeof prevMaxRaw === 'number' ? prevMaxRaw : 0;
    if (session.highestGradeNumeric <= prevMax) {
      logger.info('onSessionCreated: not a PR, skipping', {
        sessionId,
        userId: session.userId,
        prevMax,
        highestGradeNumeric: session.highestGradeNumeric,
      });
      return;
    }

    const gradeString =
      session.highestGrade.length > 0 ? session.highestGrade : `V${session.highestGradeNumeric}`;
    const actorName = await lookupDisplayName(session.userId);
    const title = `${actorName} just sent their first ${gradeString}! 🧗`;

    let totalFollowers = 0;
    for await (const page of paginateFollowers(session.userId)) {
      totalFollowers += page.length;
      for (let i = 0; i < page.length; i += PREF_CHECK_CONCURRENCY) {
        const slice = page.slice(i, i + PREF_CHECK_CONCURRENCY);
        await Promise.all(
          slice.map((recipientUid) =>
            sendNotification({
              recipientUid,
              actorUid: session.userId,
              category: 'friends',
              title,
              body: '',
              route: { kind: 'profile', userId: session.userId },
            }).catch((err: unknown) => {
              logger.warn('onSessionCreated: recipient send failed', {
                sessionId,
                recipientUid,
                err: err instanceof Error ? err.message : String(err),
              });
            })
          )
        );
      }
    }

    logger.info('onSessionCreated: F1 fan-out complete', {
      sessionId,
      userId: session.userId,
      grade: gradeString,
      totalFollowers,
    });
  }
);
