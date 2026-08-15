# Firebase / Google Sign-In Branding Checklist

Goal: the Google sign-in sheet should say **"Gecko Climbing"**, never
`gecko-climbing.firebaseapp.com`. These are one-time console steps (no code) —
they need the project owner's Google account.

## 1. OAuth consent screen (the big one)

Google Cloud Console → project **gecko-climbing** → *APIs & Services* →
*OAuth consent screen* → **Branding**:

- **App name**: `Gecko Climbing`
- **User support email**: your support address (support@ or your Gmail)
- **App logo**: 120×120 PNG of the gecko mark (use the asset from
  `public/img/gecko-logo.svg`, exported at 120×120 on a solid background)
- **App domain / links**: homepage + privacy policy URLs (the ones in
  `docs/app-store-metadata.md`)

> Uploading a logo triggers Google's one-time brand verification review
> (typically a few days). Until it clears, the consent screen may keep the
> plain look — the app name change usually applies sooner than the logo.

## 2. Firebase public-facing name

Firebase Console → *Authentication* → *Settings* → **Public-facing name** →
`Gecko Climbing`. Also confirm the support email there.

## 3. Optional: custom auth domain (removes `firebaseapp.com` entirely)

Only if you own a domain (e.g. `geckoclimbing.app`):

1. Firebase Console → *Hosting* → add custom domain `auth.geckoclimbing.app`.
2. *Authentication* → *Settings* → *Authorized domains* → add it.
3. Google Cloud Console → *Credentials* → the iOS OAuth client → add the new
   domain to the redirect configuration.
4. Ship a client update that sets `FirebaseOptions.authDomain` (or the
   equivalent GIDConfiguration) to the custom domain.

Skip this until steps 1–2 are verified — they remove the raw project id from
the *text* of the sheet, which is what users actually read.

## Related in-app fix (already shipped in `fix/follow-firebase`)

Raw Firestore/Auth errors (which can embed `…/project/gecko-climbing/…`
console URLs) are no longer shown to users — `View+ErrorAlert.swift` maps
them to friendly copy and hard-blocks anything containing URLs or the
project id.
