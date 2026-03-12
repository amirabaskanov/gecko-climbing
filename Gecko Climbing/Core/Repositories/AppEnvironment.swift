import Foundation
import SwiftUI
import SwiftData

// MARK: - App Environment (Dependency Injection Container)
@Observable
final class AppEnvironment {
    static let useMocks = false

    let authRepository: any AuthRepositoryProtocol
    let sessionRepository: any SessionRepositoryProtocol
    let climbRepository: any ClimbRepositoryProtocol
    let userRepository: any UserRepositoryProtocol
    let postRepository: any PostRepositoryProtocol
    let storageRepository: any StorageRepositoryProtocol

    init(modelContext: ModelContext) {
        #if DEBUG
        if AppEnvironment.useMocks {
            let mockAuth = MockAuthRepository()
            authRepository = mockAuth
            sessionRepository = MockSessionRepository(currentUserId: mockAuth.currentUserId)
            climbRepository = MockClimbRepository()
            userRepository = MockUserRepository(currentUserId: mockAuth.currentUserId)
            postRepository = MockPostRepository()
            storageRepository = MockStorageRepository()
            return
        }
        #endif

        let firebaseAuth = FirebaseAuthRepository()
        authRepository = firebaseAuth
        sessionRepository = FirestoreSessionRepository(authRepository: firebaseAuth)
        climbRepository = FirestoreClimbRepository()
        userRepository = FirestoreUserRepository(authRepository: firebaseAuth)
        postRepository = FirestorePostRepository(authRepository: firebaseAuth)
        storageRepository = FirebaseStorageRepository()
    }
}
