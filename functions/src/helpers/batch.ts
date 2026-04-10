// Batch primitives for coalescing notifications within a time window.
import { db } from '../admin';
import { NotificationCategory } from '../types';

export interface BatchEntry {
  actorUid: string;
  actorDisplayName: string;
  createdAtMs: number;
}

export interface BatchFlushResult {
  count: number;
  firstActorName: string;
  otherCount: number;
}

export type BatchKind = 'like';

export interface BatchContext {
  recipientUid: string;
  category: NotificationCategory;
  kind: BatchKind;
  postId?: string;
}

export interface BatchDoc {
  windowStartMs: number;
  windowMs: number;
  entries: BatchEntry[];
  recipientUid: string;
  category: NotificationCategory;
  kind: BatchKind;
  postId?: string;
}

function batchRef(bucketKey: string): FirebaseFirestore.DocumentReference {
  return db.collection('notificationBatches').doc(bucketKey);
}

export async function appendToBatch(
  bucketKey: string,
  entry: BatchEntry,
  windowMs: number,
  context?: BatchContext
): Promise<'first' | 'appended'> {
  const ref = batchRef(bucketKey);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    if (!snap.exists) {
      if (!context) {
        throw new Error(`appendToBatch: context required for first write to ${bucketKey}`);
      }
      const seed: BatchDoc = {
        windowStartMs: now,
        windowMs,
        entries: [entry],
        recipientUid: context.recipientUid,
        category: context.category,
        kind: context.kind,
        ...(context.postId !== undefined ? { postId: context.postId } : {}),
      };
      tx.set(ref, seed);
      return 'first';
    }
    const data = snap.data() as BatchDoc | undefined;
    const windowStartMs = typeof data?.windowStartMs === 'number' ? data.windowStartMs : 0;
    const existingWindowMs = typeof data?.windowMs === 'number' ? data.windowMs : windowMs;
    if (now - windowStartMs >= existingWindowMs) {
      if (!context) {
        throw new Error(`appendToBatch: context required to reseed ${bucketKey}`);
      }
      const seed: BatchDoc = {
        windowStartMs: now,
        windowMs,
        entries: [entry],
        recipientUid: context.recipientUid,
        category: context.category,
        kind: context.kind,
        ...(context.postId !== undefined ? { postId: context.postId } : {}),
      };
      tx.set(ref, seed);
      return 'first';
    }
    const entries = Array.isArray(data?.entries) ? data!.entries : [];
    tx.update(ref, { entries: [...entries, entry] });
    return 'appended';
  });
}

export async function flushBatch(bucketKey: string): Promise<BatchFlushResult | null> {
  const ref = batchRef(bucketKey);
  const snap = await ref.get();
  if (!snap.exists) {
    return null;
  }
  const data = snap.data() as BatchDoc | undefined;
  const entries: BatchEntry[] = Array.isArray(data?.entries) ? data!.entries : [];
  await ref.delete();
  if (entries.length === 0) {
    return null;
  }
  const first = entries[0];
  return {
    count: entries.length,
    firstActorName: first.actorDisplayName,
    otherCount: entries.length - 1,
  };
}

export async function listExpiredBatches(
  nowMs: number
): Promise<Array<{ id: string; doc: BatchDoc }>> {
  const snap = await db.collection('notificationBatches').limit(50).get();
  const expired: Array<{ id: string; doc: BatchDoc }> = [];
  snap.forEach((s) => {
    const data = s.data() as BatchDoc | undefined;
    if (!data) {
      return;
    }
    const windowStartMs = typeof data.windowStartMs === 'number' ? data.windowStartMs : 0;
    const windowMs = typeof data.windowMs === 'number' ? data.windowMs : 0;
    if (windowStartMs + windowMs <= nowMs) {
      expired.push({ id: s.id, doc: data });
    }
  });
  return expired;
}

export async function deleteBatch(bucketKey: string): Promise<void> {
  await batchRef(bucketKey).delete();
}
