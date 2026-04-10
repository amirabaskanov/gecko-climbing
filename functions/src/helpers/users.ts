// Display name lookup used by all social triggers for actor copy.
import { db } from '../admin';

export async function lookupDisplayName(uid: string): Promise<string> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) {
    return 'Someone';
  }
  const data = snap.data();
  const displayName = data?.displayName;
  if (typeof displayName === 'string' && displayName.length > 0) {
    return displayName;
  }
  const username = data?.username;
  if (typeof username === 'string' && username.length > 0) {
    return username;
  }
  return 'Someone';
}
