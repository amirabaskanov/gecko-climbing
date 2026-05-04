NEW IN THIS BUILD

Dark mode: the whole app now supports dark appearance. Try flipping iOS system appearance to see it.

Push notifications: you'll now get notified when friends log sessions, like your posts, comment on you, follow you, or mention you in a comment. Tap "Enable Notifications" in Profile then Settings when prompted.

Gentle reminders: weekly recap of your climbing, plus a nudge if you haven't logged a session in a while.

Attempts visualization: failed attempts now show as hatched pills on the feed and session rows, alongside sends and flashes.

Session drafts persist: if the app gets killed mid-session, your logged climbs will be restored when you reopen.

Friend-activity notification sub-toggle in settings if you want friend posts but not everything else.


FIXED

- Dark mode and UI polish across the app
- Cross-provider sign-in (e.g. you signed up with Google but try Apple) now shows a clear error explaining which method to use
- Deleting a session now also removes its feed post, no more orphaned posts
- Signing out and into a different account no longer mixes up drafts between users
- Post-save failures now show an error alert instead of silently disappearing
- Apple Sign-In and storage init no longer crash the app on rare failures, you'll see an error screen instead
- Profile, Stats, Social, and Followers screens now show errors instead of spinning forever on network failures
- Session detail now sorts climbs correctly
- Smoother feed scrolling on first load


REMOVED

- Daily streak in Stats (we're reworking how streaks work)


PLEASE SPECIFICALLY TEST

1. Turn on push notifications when prompted, then have a friend like or comment on a post, confirm you get the push
2. Sign out and in as a different account, start logging, make sure no old climbs reappear
3. Delete a session you've shared to the feed, confirm the post also disappears
4. Try dark mode (Settings, Display and Brightness, Dark)
5. Force-quit the app mid-session, reopen and verify your climbs are still there
