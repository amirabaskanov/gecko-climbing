// Reads user notification preferences; categories default to enabled when unset.
import { db } from '../admin';
import { NotificationCategory } from '../types';

export async function isCategoryEnabled(
  uid: string,
  category: NotificationCategory
): Promise<boolean> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) {
    return true;
  }
  const data = snap.data();
  const prefs = data?.notificationPrefs as Record<string, unknown> | undefined;
  if (!prefs) {
    return true;
  }
  const value = prefs[category];
  if (value === undefined || value === null) {
    return true;
  }
  return value !== false;
}
