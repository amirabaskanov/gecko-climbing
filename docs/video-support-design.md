# Video Support — Design Doc (not yet implemented)

Status: **design only** (decided 2026-08-14). Video posts are a separate
project to be scheduled after the feedback-round-1 work ships. This doc is the
implementation contract so the build is mechanical when we green-light it.

## Goal

Climbers post short clips of sends alongside (or instead of) photos in the
session feed. Watch in-feed with a poster frame; tap for full-screen playback.

## Data model

`PostModel` / `PostDTO` gain optional media fields (all nil for photo-only
posts — fully backward compatible, no migration):

| Field | Type | Notes |
|---|---|---|
| `videoURL` | `String?` | Firebase Storage download URL (H.264/HEVC mp4) |
| `videoThumbURL` | `String?` | Poster JPEG, generated client-side at upload |
| `videoDurationSec` | `Double?` | For the duration chip on the poster |

Feed rendering rule: if `videoURL` exists → video cell with poster +
play button; else existing `imageURLs` carousel. One video per post in v1
(keeps upload/compression UX simple; carousel-of-videos is v2).

## Storage

- Path: `users/{uid}/videos/{postId}.mp4` + `users/{uid}/videos/{postId}-poster.jpg`
- `storage.rules` addition (current rules block everything non-image at 10 MB):

```
match /users/{uid}/videos/{fileName} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == uid
    && request.resource.size < 100 * 1024 * 1024
    && (request.resource.contentType.matches('video/(mp4|quicktime)')
        || request.resource.contentType.matches('image/jpeg')); // poster
}
```

- Client-side compression before upload: `AVAssetExportSession` with
  `AVAssetExportPreset1280x720` (~720p, keeps most clips under ~25 MB/min).
  Hard cap clip length at 60s in the picker (`PhotosPicker` `.videos` filter +
  duration check after load).
- Poster: `AVAssetImageGenerator` frame at t=0.5s, JPEG q0.7, ≤200 KB.

## Client

- Picker: extend `SessionDetailsForm` photo section — `PhotosPicker(matching:
  .any(of: [.images, .videos]))`, transferable `Movie` type.
- Upload: new `StorageRepositoryProtocol` methods `uploadPostVideo(userId:postId:fileURL:)`
  and `uploadPostVideoPoster(...)`; progress via `StorageUploadTask` surfaced
  in the celebration sheet (videos are big — silent uploads feel broken).
- Playback: `FeedCardView` media section renders poster via existing
  `AsyncImageView` + play overlay; tap → full-screen `AVKit.VideoPlayer` in a
  sheet. **No feed autoplay in v1** (data + battery + muted-audio design all
  deferred).
- Offline: video upload queues like session drafts? **No** — v1 requires
  connectivity at post time; the post saves without video on failure (photo
  fallback), with a retry affordance. Keep it simple.

## Server / cost

- No Cloud Function transcoding in v1 (client compresses). If quality issues
  appear, add a Storage-triggered transcode function later (Transcoder API or
  ffmpeg in Cloud Run — revisit with real usage data).
- Cost envelope at small scale: Storage ~$0.026/GB/mo + egress ~$0.12/GB.
  1,000 clips × 25 MB = 25 GB ≈ $0.65/mo storage; egress dominated by watch
  count — with poster-first rendering only actual plays download the video.
- Moderation: same report/block pipeline as photos (`reports` collection).
  Add `videoURL` to the report payload. Pre-publish scanning deferred.

## Push / feed metadata

- `PostPayload` builder sets the three new fields; `gradeCounts`/`gradeSequence`
  unchanged.
- `batchSweeper`/notification copy unchanged (no video-specific pushes in v1).

## Rollout order (when implemented)

1. DTO/model fields + rules deploy (backward compatible, ship silently).
2. Playback support in feed (old clients ignore unknown fields — verify).
3. Upload UI last, ideally behind a TestFlight build first.

## Explicitly out of scope for v1

Feed autoplay, multi-video posts, server transcoding, comments-on-timestamp,
download/save-to-camera-roll, video in Week in Review cards.
