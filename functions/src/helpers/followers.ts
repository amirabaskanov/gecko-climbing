// Paginated follower UID iterator used by fan-out triggers (F1, F2).
import { db } from '../admin';

export async function* paginateFollowers(
  uid: string,
  pageSize: number = 500
): AsyncGenerator<string[], void, void> {
  const collRef = db.collection('users').doc(uid).collection('followers');
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  while (true) {
    let query: FirebaseFirestore.Query = collRef.orderBy('__name__').limit(pageSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    const snap = await query.get();
    if (snap.empty) {
      return;
    }
    const ids: string[] = snap.docs.map((d) => d.id);
    yield ids;
    if (snap.size < pageSize) {
      return;
    }
    cursor = snap.docs[snap.docs.length - 1];
  }
}

export async function friendPostsOptedIn(recipientUid: string): Promise<boolean> {
  const snap = await db.collection('users').doc(recipientUid).get();
  if (!snap.exists) {
    return false;
  }
  const prefs = snap.data()?.notificationPrefs as Record<string, unknown> | undefined;
  if (!prefs) {
    return false;
  }
  return prefs.friendPosts === true;
}
