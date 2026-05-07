import Foundation
import SwiftUI
import SwiftData

// MARK: - App Environment (Dependency Injection Container)

/// Holds all repositories the app depends on. Production builds wire up Firebase
/// implementations; SwiftUI previews use the `.preview` factory to get fully
/// mocked repositories with realistic seed data so previews work without Firebase.
@Observable
final class AppEnvironment {
    let authRepository: any AuthRepositoryProtocol
    let sessionRepository: any SessionRepositoryProtocol
    let climbRepository: any ClimbRepositoryProtocol
    let userRepository: any UserRepositoryProtocol
    let postRepository: any PostRepositoryProtocol
    let storageRepository: any StorageRepositoryProtocol
    let feedbackRepository: any FeedbackRepositoryProtocol

    /// Production initializer — wires Firebase-backed repositories. The
    /// `modelContext` parameter is accepted for call-site compatibility but
    /// no longer used; repositories no longer depend on SwiftData directly.
    init(modelContext: ModelContext? = nil) {
        _ = modelContext
        let firebaseAuth = FirebaseAuthRepository()
        authRepository = firebaseAuth
        sessionRepository = FirestoreSessionRepository(authRepository: firebaseAuth)
        climbRepository = FirestoreClimbRepository()
        userRepository = FirestoreUserRepository(authRepository: firebaseAuth)
        postRepository = FirestorePostRepository(authRepository: firebaseAuth)
        storageRepository = FirebaseStorageRepository()
        feedbackRepository = FirestoreFeedbackRepository()
    }

    #if DEBUG
    /// Private mock initializer used by `.preview` and `.screenshotMode`. Wires
    /// up mock repositories pre-authenticated as the given user so preview
    /// screens (and screenshot-mode runs) render real data paths without
    /// hitting Firebase.
    private init(mockCurrentUserId: String, mockDisplayName: String) {
        let mockAuth = MockAuthRepository.previewAuthenticated(
            userId: mockCurrentUserId,
            displayName: mockDisplayName
        )
        authRepository = mockAuth
        sessionRepository = MockSessionRepository(currentUserId: mockAuth.currentUserId)
        climbRepository = MockClimbRepository()
        userRepository = MockUserRepository(currentUserId: mockAuth.currentUserId)
        postRepository = MockPostRepository()
        storageRepository = MockStorageRepository()
        feedbackRepository = MockFeedbackRepository()
    }

    /// Fully mocked environment for SwiftUI previews. Safe to call repeatedly;
    /// each call returns an independent instance with fresh seed data.
    @MainActor
    static var preview: AppEnvironment {
        AppEnvironment(mockCurrentUserId: "preview_user", mockDisplayName: "Preview Climber")
    }

    /// Screenshot-mode environment for App Store / marketing captures. Boots
    /// the running app with rich seed data (Kai Mendez's account + 4 follower
    /// climbers, photos, sessions, comments). Activated at launch via the
    /// `-screenshotMode YES` argument — see `GeckoClimbingApp.init`.
    @MainActor
    static var screenshotMode: AppEnvironment {
        AppEnvironment(mockCurrentUserId: MockSeed.kaiUserId, mockDisplayName: MockSeed.kaiDisplayName)
    }

    /// True when the process was launched with `-screenshotMode YES` (Xcode
    /// scheme arg or `xcrun simctl launch ... -screenshotMode YES`). Inspected
    /// at app boot to decide whether to wire mock repositories.
    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    /// Convenience: a matching `AuthViewModel` already authenticated for the
    /// preview environment, so previews land directly on signed-in UI.
    @MainActor
    static func previewAuth(_ env: AppEnvironment) -> AuthViewModel {
        AuthViewModel(authRepository: env.authRepository)
    }
    #endif
}

// MARK: - Mock Seed Constants

/// Centralised cast and constants for screenshot-mode / SwiftUI-preview seed
/// data. The Mock repositories pull from here so the same Kai/Riley/Maya/
/// Jordan/Sam identities show up consistently in users, posts, comments,
/// follows, and sessions.
///
/// Available in Release builds because the Mock repository implementations
/// (which reference these constants) are not themselves DEBUG-gated. The
/// constants are inert string identifiers — no security or size cost from
/// shipping them.
enum MockSeed {

    // MARK: - The cast

    static let kaiUserId = "kai_mendez"
    static let kaiDisplayName = "Kai Mendez"

    static let rileyUserId = "riley_brooks"
    static let rileyDisplayName = "Riley Brooks"

    static let mayaUserId = "maya_tanaka"
    static let mayaDisplayName = "Maya Tanaka"

    static let jordanUserId = "jordan_reyes"
    static let jordanDisplayName = "Jordan Reyes"

    static let marcoUserId = "marco_park"
    static let marcoDisplayName = "Marco Park"

    static let naomiUserId = "naomi_cole"
    static let naomiDisplayName = "Naomi Cole"

    // MARK: - Bundle photo refs (resolved by `Image.bundled(from:)`)

    static let kaiAvatar = "bundle:kai-avatar"
    static let climbIndoorMale1 = "bundle:climb-indoor-male-1"
    static let climbIndoorMale2 = "bundle:climb-indoor-male-2"
    static let climbIndoorFemale1 = "bundle:climb-indoor-female-1"
    static let climbOutdoorFemale = "bundle:climb-outdoor-female"
    static let climbOutdoorMale = "bundle:climb-outdoor-male"
    static let gymCRGHarvard = "bundle:gym-crg-harvard"
    static let gymHollywood = "bundle:gym-hollywood"

    // MARK: - Cast lookup

    /// Display name for a given mock user ID. Used by post/comment seeders so
    /// denormalized author fields stay in sync with `UserModel.displayName`.
    static func displayName(for userId: String) -> String {
        switch userId {
        case kaiUserId: return kaiDisplayName
        case rileyUserId: return rileyDisplayName
        case mayaUserId: return mayaDisplayName
        case jordanUserId: return jordanDisplayName
        case marcoUserId: return marcoDisplayName
        case naomiUserId: return naomiDisplayName
        default: return ""
        }
    }

    /// Profile image URL (bundle ref) for a given mock user. Three of the six
    /// climbers have photos; Maya, Jordan, and Naomi fall through to initials
    /// avatars so the cast feels real (not everyone sets a profile photo).
    static func avatarURL(for userId: String) -> String {
        switch userId {
        case kaiUserId: return kaiAvatar
        case rileyUserId: return climbIndoorFemale1
        case marcoUserId: return climbOutdoorMale
        default: return ""
        }
    }
}
