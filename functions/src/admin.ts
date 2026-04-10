// Firebase Admin SDK singleton — initialized once, reused across handlers.
import * as admin from 'firebase-admin';

admin.initializeApp();

export const db = admin.firestore();
export const messaging = admin.messaging();
