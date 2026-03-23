import Foundation
import Observation
import UIKit
import GoogleSignIn

@Observable @MainActor
final class AuthViewModel {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var error: Error?

    private let authRepository: any AuthRepositoryProtocol

    var currentUserId: String { authRepository.currentUserId }
    var currentUserDisplayName: String { authRepository.currentUserDisplayName }

    init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
        self.isAuthenticated = authRepository.isAuthenticated
        authRepository.addAuthStateListener { [weak self] isAuthenticated in
            DispatchQueue.main.async {
                self?.isAuthenticated = isAuthenticated
                if isAuthenticated, let self {
                    AnalyticsService.identify(userId: self.currentUserId, properties: [
                        "display_name": self.currentUserDisplayName
                    ])
                }
            }
        }
    }

    deinit {
        authRepository.removeAuthStateListener()
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil
        do {
            try await authRepository.signIn(email: email, password: password)
            AnalyticsService.capture(.signIn, properties: ["method": "email"])
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        error = nil
        do {
            let base = displayName
                .lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            let suffix = String(UUID().uuidString.prefix(6).lowercased())
            let username = "\(base)_\(suffix)"
            try await authRepository.signUp(email: email, password: password, username: username, displayName: displayName)
            AnalyticsService.capture(.signUp, properties: ["method": "email"])
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func signOut() {
        do {
            try authRepository.signOut()
            AnalyticsService.capture(.signOut)
            AnalyticsService.reset()
        } catch {
            self.error = error
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        error = nil
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                throw AuthError.cancelled
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.tokenMissing
            }
            let accessToken = result.user.accessToken.tokenString
            try await authRepository.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            AnalyticsService.capture(.signIn, properties: ["method": "google"])
        } catch let gidError as GIDSignInError where gidError.code == .canceled {
            // User cancelled — no error shown
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async {
        isLoading = true
        error = nil
        do {
            try await authRepository.signInWithApple(idToken: idToken, rawNonce: rawNonce, fullName: fullName)
            AnalyticsService.capture(.signIn, properties: ["method": "apple"])
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func clearError() {
        error = nil
    }
}
