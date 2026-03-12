# Gecko Climbing — Gap Analysis & Skills Roadmap

## High-Impact Gaps

### 1. No Real Backend — Everything is Mocked
All repositories (auth, sessions, climbs, users, posts, storage) return fake data. No actual persistence beyond the device.
- `/ios-networking` — URLSession patterns for API calls
- `/cloudkit-sync` — If you want iCloud sync instead of/alongside Firebase
- `/codable-patterns` — Clean DTO encoding/decoding for your Firebase or API layer
- `/authentication` — Real Sign in with Apple flow (yours is stubbed)

### 2. No Tests
`GeckoClimbingTests.swift` exists but is essentially empty.
- `/swift-testing` — Modern `@Test`/`#expect` framework for unit + UI tests
- `/debugging-instruments` — Profile performance, find memory leaks

### 3. No Offline/Sync Strategy
`isSyncedToFirestore` flag exists on SessionModel but sync logic is unimplemented.
- `/swiftdata` — You're using SwiftData but could leverage `#Predicate`, `FetchDescriptor`, and history tracking more
- `/background-processing` — `BGTaskScheduler` to sync sessions when the app is backgrounded

### 4. No Push Notifications
No way to notify users about social activity (likes, follows, new sessions from friends).
- `/push-notifications` — APNs setup, local + remote notifications, rich notifications

### 5. No Photo/Camera Integration
`photoURL` fields exist on climbs and posts but uploads are mocked.
- `/photos-camera-media` — PhotosPicker, camera capture, image handling

---

## Medium-Impact Gaps

### 6. No Widgets or Live Activities
A climbing session timer is a perfect Live Activity / Dynamic Island candidate.
- `/widgetkit` — Home screen widgets showing streak, recent session stats
- `/live-activities` — Show active session timer on Lock Screen / Dynamic Island

### 7. No HealthKit Integration
Climbing is exercise — session data could sync to Apple Health.
- `/healthkit` — Write workout samples, read activity data

### 8. Charts Could Be Richer
GradePyramidView and ProgressChartView exist but are basic.
- `/swift-charts` — Selection, scrolling, annotations, more chart types

### 9. No Accessibility Work
No VoiceOver labels, no Dynamic Type considerations on custom components like GradeBarrelView.
- `/ios-accessibility` — VoiceOver, accessibility labels, traits, Dynamic Type

### 10. No Haptics or Advanced Animations
geckoSpring/geckoSnappy exist but no haptic feedback on grade selection or climb logging.
- `/swiftui-animation` — Phase animators, keyframe animations, matched geometry
- `/swiftui-gestures` — Better drag/swipe interactions on the barrel view

---

## Nice-to-Have Gaps

| Gap | Skill |
|-----|-------|
| No in-app purchases (premium features, gym partnerships) | `/storekit` |
| No Siri/Shortcuts integration ("Log a V5 flash") | `/app-intents` |
| No location-based gym detection | `/mapkit-location` |
| Comments system is UI-only, no implementation | `/swiftui-patterns` |
| No onboarding/feature tips | `/tipkit` |
| No App Clip for gym kiosks | `/app-clips` |
| No localization | `/ios-localization` |
| Settings view is a stub | `/swiftui-navigation` |
| Wall analysis view is empty | `/vision-framework` + `/coreml` (photo-based route analysis) |
| No App Store prep | `/app-store-review` |
| Swift 6 concurrency not adopted | `/swift-concurrency` |

---

## Top 3 Priorities
1. **Real backend/sync** — Transforms from prototype to functional app
2. **Live Activities for session timer** — Killer feature for active climbing sessions
3. **Photo capture for climb logging** — Social engagement driver
