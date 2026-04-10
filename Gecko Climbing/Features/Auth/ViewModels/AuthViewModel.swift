import Foundation
import Observation
import UIKit
import GoogleSignIn
import AuthenticationServices
import OSLog

private let authVMLog = Logger(subsystem: "com.geckoclimbing.app", category: "AuthVM")

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
            trackSignInFailure(method: "email", error: error)
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
            trackSignInFailure(method: "email_signup", error: error)
            self.error = error
        }
        isLoading = false
    }

    func signOut() {
        // Capture the userId BEFORE we drop Firebase auth — once we sign out the
        // repository's currentUserId reverts to empty and we'd lose the key we
        // need to wipe the per-user session draft.
        let userIdToWipe = authRepository.currentUserId
        do {
            try authRepository.signOut()
            // Belt-and-suspenders: even though drafts are now namespaced by userId,
            // wipe the previous user's draft so a shared device can't leave a
            // restorable in-progress session sitting in UserDefaults.
            if !userIdToWipe.isEmpty {
                NewSessionViewModel.wipeDraft(for: userIdToWipe)
            }
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
            trackSignInFailure(method: "google", error: error)
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
            authVMLog.error("signInWithApple threw: \(String(describing: error), privacy: .public)")
            trackSignInFailure(method: "apple", error: error)
            self.error = error
        }
        isLoading = false
    }

    private func trackSignInFailure(method: String, error: Error) {
        var props: [String: Any] = ["method": method, "reason": String(describing: type(of: error))]
        if let authError = error as? AuthError {
            switch authError {
            case .accountExistsWithDifferentCredential(_, let providers):
                props["reason"] = "account_exists_with_different_credential"
                props["existing_providers"] = providers
            case .providerNotEnabled:
                props["reason"] = "provider_not_enabled"
            case .appleAuthorizationFailed:
                props["reason"] = "apple_authorization_failed"
            case .tokenMissing:
                props["reason"] = "token_missing"
            case .networkError:
                props["reason"] = "network_error"
            case .invalidCredentials:
                props["reason"] = "invalid_credentials"
            case .unknown(let message):
                props["reason"] = "unknown"
                props["message"] = message
            default:
                break
            }
        }
        AnalyticsService.capture(.signInFailed, properties: props)
    }

    /// Call from ASAuthorizationController completion when the authorization itself fails
    /// (i.e. before we ever hit Firebase). Filters user-cancel so we don't nag them.
    func handleAppleAuthorizationFailure(_ error: Error) {
        if let authError = error as? ASAuthorizationError {
            authVMLog.error("ASAuthorizationError code=\(authError.errorCode, privacy: .public) desc=\(authError.localizedDescription, privacy: .public)")
            if authError.code == .canceled {
                return
            }
            self.error = AuthError.appleAuthorizationFailed(authError.localizedDescription)
        } else {
            authVMLog.error("Apple authorization failed (non-ASAuthorizationError): \(String(describing: error), privacy: .public)")
            self.error = AuthError.appleAuthorizationFailed(error.localizedDescription)
        }
    }

    /// Call when Apple returns success but the identity token is missing/undecodable.
    func handleAppleTokenMissing() {
        authVMLog.error("Apple Sign-In success but identityToken was missing or not UTF-8 decodable")
        self.error = AuthError.tokenMissing
    }

    func clearError() {
        error = nil
    }
}
