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
    /// Private mock initializer used by `.preview`. Wires up mock repositories
    /// pre-authenticated as a fake user so preview screens render real data
    /// paths without hitting Firebase.
    private init(previewMarker: Void) {
        let mockAuth = MockAuthRepository.previewAuthenticated()
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
        AppEnvironment(previewMarker: ())
    }

    /// Convenience: a matching `AuthViewModel` already authenticated for the
    /// preview environment, so previews land directly on signed-in UI.
    @MainActor
    static func previewAuth(_ env: AppEnvironment) -> AuthViewModel {
        AuthViewModel(authRepository: env.authRepository)
    }
    #endif
}
