# Gecko Climbing - iOS App

## Project Overview
Climbing tracking app for iOS. Users log climbing sessions with V-grades, track progress, and share with friends.

## Architecture
- **Pattern**: MVVM with protocol-based repositories
- **UI**: SwiftUI (iOS 17+ with @Observable)
- **Persistence**: SwiftData (SessionModel, ClimbModel, UserModel, PostModel)
- **Auth**: Firebase Auth + Google Sign-In + Sign in with Apple
- **DI**: AppEnvironment container injected via .environment()
- **Navigation**: NavigationStack with route enums per tab (TabRouter)

## Project Structure
```
Gecko Climbing/
├── App/           — Entry point, routing, tab config
├── Core/
│   ├── DTOs/      — Codable structs for API ↔ Model bridging
│   ├── Extensions/— Color+Brand, View+ErrorAlert, Animation+Gecko, Date+Formatted
│   ├── Models/    — SwiftData @Model classes
│   └── Repositories/ — Protocol + Mock implementations, AppEnvironment DI
├── Features/      — Feature modules (Auth, Home, Session, Profile, Social, Stats, WallAnalysis)
│   └── <Feature>/
│       ├── ViewModels/
│       └── Views/
└── Shared/
    ├── Components/ — Reusable views (GradeBarrelView, ClimbPillView, ConfettiView, etc.)
    └── Layout/     — MainTabView, CustomTabBar, FlowLayout
```

## Key Conventions
- ViewModels: `@Observable final class`, named `*ViewModel`
- Repositories: protocol `*RepositoryProtocol` + `Mock*Repository` for testing
- Models: SwiftData `@Model` classes named `*Model`
- DTOs: `*DTO` with `toModel()` and `asDictionary()` methods
- Colors: Use `Color.geckoPrimary` (coral red brand), `Color.geckoSentGreen` (success/sent), `Color.geckoFlashGold`, etc. from Color+Brand.swift. Legacy `Color.geckoGreen` aliases to `geckoPrimary`
- Logo: Use `GeckoLogoView(size:color:showWordmark:)` from Shared/Components/GeckoLogoView.swift
- Font: `.design(.rounded)` for brand text (SF Pro Rounded)
- Animations: Use `Animation.geckoSpring`, `.geckoSnappy`, `.geckoBounce` from Animation+Gecko.swift
- Error handling: ViewModels expose `error: Error?`, views use `.errorAlert(error:)` modifier
- Async: `async throws` with `@MainActor` for UI updates

## Climbing Domain
- Grades: V0-V17 (Hueco scale). `gradeNumeric` is the integer, `grade` is the "V5" string
- Outcomes: flash (1 attempt), sent (2+ attempts), project (working on it), attempt (didn't complete)
- Sessions: contain multiple climbs, track duration, gym name, stats

## Build & Run
- **Scheme**: Gecko Climbing
- **Default Simulator**: iPhone 16 Pro (iOS 18.3)
- XcodeBuildMCP is configured — use `build_run_sim` to build and run
- Use `screenshot` and `snapshot_ui` to inspect the running app visually

## Dependencies (SPM)
- FirebaseCore, FirebaseAuth
- GoogleSignIn

## Mock Mode
- `AppEnvironment.useMocks = false` — toggle in AppEnvironment.swift
- Mock repositories generate realistic seed data for development
