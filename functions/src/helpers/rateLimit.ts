// Per-user sliding-window rate limiter — max 5 notifications per hour across all categories.
import { db } from '../admin';
import { NotificationCategory } from '../types';

const WINDOW_MS = 60 * 60 * 1000;
const MAX_PER_WINDOW = 5;

export async function checkAndConsumeRateLimit(
  uid: string,
  _category: NotificationCategory
): Promise<boolean> {
  const ref = db.collection('rateLimits').doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.exists ? snap.data() : undefined;
    const windowStartMs = typeof data?.windowStartMs === 'number' ? (data.windowStartMs as number) : 0;
    const count = typeof data?.count === 'number' ? (data.count as number) : 0;

    if (!snap.exists || now - windowStartMs >= WINDOW_MS) {
      tx.set(ref, { windowStartMs: now, count: 1 });
      return true;
    }

    const next = count + 1;
    if (next > MAX_PER_WINDOW) {
      return false;
    }
    tx.update(ref, { count: next });
    return true;
  });
}
