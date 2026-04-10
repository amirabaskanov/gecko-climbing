// Batch primitives for coalescing notifications within a time window.
// NOTE: This module provides append/flush primitives only. Callers are responsible for
// arranging `flushBatch` to run after `windowMs` (e.g. via Cloud Tasks or scheduled functions).
// The scheduling mechanism is intentionally not implemented in this scaffold — see Phases 2b/2c.
import { db } from '../admin';

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

interface BatchDoc {
  windowStartMs: number;
  entries: BatchEntry[];
}

function batchRef(bucketKey: string): FirebaseFirestore.DocumentReference {
  return db.collection('notificationBatches').doc(bucketKey);
}

export async function appendToBatch(
  bucketKey: string,
  entry: BatchEntry,
  windowMs: number
): Promise<'first' | 'appended'> {
  const ref = batchRef(bucketKey);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    if (!snap.exists) {
      tx.set(ref, { windowStartMs: now, entries: [entry] });
      return 'first';
    }
    const data = snap.data() as BatchDoc | undefined;
    const windowStartMs = typeof data?.windowStartMs === 'number' ? data.windowStartMs : 0;
    if (now - windowStartMs >= windowMs) {
      tx.set(ref, { windowStartMs: now, entries: [entry] });
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
