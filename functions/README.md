# Gecko Climbing — Cloud Functions

Firebase Cloud Functions (v2) powering push notifications for the Gecko Climbing iOS app. This directory currently contains the scaffold and shared helpers only; triggers land here in Phases 2b (social) and 2c (friend activity).

## Prerequisites

- Node 20
- Firebase CLI: `npm install -g firebase-tools`
- Sign in: `firebase login`
- Select project: `firebase use gecko-climbing`

## One-time setup

```
cd functions
npm install
```

## Build

```
npm run build
```

Outputs compiled JS to `lib/`. `npm run build:watch` keeps it running.

## Local development

```
npm run serve
```

Starts the Firebase emulator suite for functions. Use alongside the Firestore emulator if you need end-to-end flows.

## Deploy

```
npm run deploy
```

Runs `firebase deploy --only functions` (predeploy hook compiles TS first).

## Firestore data shapes the helpers expect

- `users/{uid}.fcmTokens: string[]` — written by iOS on APNs registration (arrayUnion).
- `users/{uid}.notificationPrefs: { social: bool, friends: bool, reminders: bool }` — written by iOS user settings. Missing fields default to enabled.
- `users/{uid}.timeZone: string` — IANA timezone (e.g. `"America/Denver"`). **Not yet written by the iOS client.** Until the iOS follow-up ships, quiet hours default to UTC boundaries (10pm–8am UTC), which will not match user local time.
- `rateLimits/{uid}` — managed by `helpers/rateLimit.ts`. Schema: `{ windowStartMs: number, count: number }`.
- `notificationBatches/{bucketKey}` — managed by `helpers/batch.ts`. Schema: `{ windowStartMs: number, entries: BatchEntry[] }`.

## Helpers overview

- `src/admin.ts` — Admin SDK singleton (`db`, `messaging`).
- `src/types.ts` — Shared notification types and `encodeRoute()` matching the iOS payload parser.
- `src/helpers/prefs.ts` — `isCategoryEnabled(uid, category)`.
- `src/helpers/quietHours.ts` — `isInQuietHours(uid)` (10pm–8am local).
- `src/helpers/rateLimit.ts` — `checkAndConsumeRateLimit(uid, category)` (5/hour transactional).
- `src/helpers/fcm.ts` — `sendNotification(opts)` central pipeline with pref/quiet/rate gates and invalid-token pruning.
- `src/helpers/batch.ts` — `appendToBatch` / `flushBatch` primitives. Callers must arrange flush scheduling; the scheduling mechanism is deliberately out of scope for this scaffold.
