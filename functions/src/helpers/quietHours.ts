// Quiet hours check — 10pm–8am local in the user's IANA timezone (defaults to UTC).
import { db } from '../admin';

export async function isInQuietHours(uid: string): Promise<boolean> {
  const snap = await db.collection('users').doc(uid).get();
  const timeZoneRaw = snap.exists ? (snap.data()?.timeZone as unknown) : undefined;
  const timeZone = typeof timeZoneRaw === 'string' && timeZoneRaw.length > 0 ? timeZoneRaw : 'UTC';

  let hour: number;
  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour: '2-digit',
      hour12: false,
    });
    const parts = formatter.formatToParts(new Date());
    const hourPart = parts.find((p) => p.type === 'hour');
    hour = hourPart ? parseInt(hourPart.value, 10) : NaN;
    if (Number.isNaN(hour)) {
      hour = new Date().getUTCHours();
    } else if (hour === 24) {
      hour = 0;
    }
  } catch {
    hour = new Date().getUTCHours();
  }

  return hour >= 22 || hour < 8;
}
