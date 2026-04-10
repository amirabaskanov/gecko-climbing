import Foundation
import FirebaseAuth
import GoogleSignIn
import OSLog

private let authLog = Logger(subsystem: "com.geckoclimbing.app", category: "Auth")

// MARK: - Firebase Auth Repository
final class FirebaseAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    var isAuthenticated: Bool { Auth.auth().currentUser != nil }
    var currentUserDisplayName: String { Auth.auth().currentUser?.displayName ?? "" }

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch let error as NSError {
            throw mapFirebaseError(error, flow: .emailPassword)
        }
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        } catch let error as NSError {
            throw mapFirebaseError(error, flow: .emailPassword)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch let error as NSError {
            throw mapFirebaseError(error, flow: .emailPassword)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        do {
            try await Auth.auth().signIn(with: credential)
        } catch let error as NSError {
            authLog.error("Google Sign-In failed: domain=\(error.domain, privacy: .public) code=\(error.code, privacy: .public) desc=\(error.localizedDescription, privacy: .public)")
            throw await resolveAuthError(error, flow: .google)
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        do {
            let result = try await Auth.auth().signIn(with: credential)
            authLog.info("Apple Sign-In succeeded for uid=\(result.user.uid, privacy: .public)")
            // Backfill a display name for returning Apple users. Apple only returns `fullName`
            // on the *first* authorization per Apple ID + bundle ID. Any subsequent sign-in
            // (including after reinstall) yields nil, leaving Firebase user.displayName empty
            // and the Firestore profile defaulting to "Gecko Climber".
            let existingDisplayName = result.user.displayName ?? ""
            if existingDisplayName.isEmpty {
                let fallback = derivedDisplayName(fullName: fullName, email: result.user.email)
                if !fallback.isEmpty {
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = fallback
                    try? await changeRequest.commitChanges()
                    authLog.info("Backfilled Apple displayName to \(fallback, privacy: .public)")
                }
            }
        } catch let error as NSError {
            authLog.error("Apple Sign-In failed: domain=\(error.domain, privacy: .public) code=\(error.code, privacy: .public) desc=\(error.localizedDescription, privacy: .public)")
            throw await resolveAuthError(error, flow: .apple)
        }
    }

    /// Wraps `mapFirebaseError` to add an async lookup of existing sign-in providers
    /// when Firebase reports a cross-provider collision. Only used on Apple/Google paths
    /// because `accountExistsWithDifferentCredential` only fires on OAuth flows.
    private func resolveAuthError(_ error: NSError, flow: AuthFlow) async -> AuthError {
        let code = AuthErrorCode(rawValue: error.code)
        if code == .accountExistsWithDifferentCredential || code == .credentialAlreadyInUse {
            let email = error.userInfo[AuthErrorUserInfoEmailKey] as? String
            let providers = await fetchSignInProviders(forEmail: email)
            authLog.info("Cross-provider collision email=\(email ?? "nil", privacy: .public) existingProviders=\(providers, privacy: .public)")
            return .accountExistsWithDifferentCredential(email: email, existingProviders: providers)
        }
        return mapFirebaseError(error, flow: flow)
    }

    private func fetchSignInProviders(forEmail email: String?) async -> [String] {
        guard let email, !email.isEmpty else { return [] }
        do {
            return try await Auth.auth().fetchSignInMethods(forEmail: email)
        } catch {
            authLog.error("fetchSignInMethods failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func derivedDisplayName(fullName: PersonNameComponents?, email: String?) -> String {
        if let fullName {
            let given = fullName.givenName ?? ""
            let family = fullName.familyName ?? ""
            let combined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            if !combined.isEmpty { return combined }
        }
        if let email, let local = email.split(separator: "@").first {
            // Apple private relay emails look like `xxxxx@privaterelay.appleid.com` —
            // the local part is an opaque hash, not useful as a display name.
            let localString = String(local)
            if !email.contains("@privaterelay.appleid.com") && !localString.isEmpty {
                return localString
            }
        }
        return ""
    }

    func addAuthStateListener(_ listener: @escaping (Bool) -> Void) {
        listenerHandle = Auth.auth().addStateDidChangeListener { _, user in
            listener(user != nil)
        }
    }

    func removeAuthStateListener() {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            listenerHandle = nil
        }
    }

    // MARK: - Private

    private enum AuthFlow { case emailPassword, google, apple }

    private func mapFirebaseError(_ error: NSError, flow: AuthFlow = .emailPassword) -> AuthError {
        let code = AuthErrorCode(rawValue: error.code)
        switch code {
        case .wrongPassword, .userNotFound:
            return .invalidCredentials
        case .invalidCredential:
            // For OAuth flows (Apple/Google), `invalidCredential` means the ID token was
            // rejected (expired, nonce mismatch, clock skew). "Invalid email or password"
            // would be nonsense.
            switch flow {
            case .emailPassword: return .invalidCredentials
            case .apple: return .appleAuthorizationFailed("Apple rejected the sign-in. Please try again.")
            case .google: return .unknown("Google rejected the sign-in. Please try again.")
            }
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .networkError:
            return .networkError
        case .accountExistsWithDifferentCredential, .credentialAlreadyInUse:
            // Defensive fallback if someone calls mapFirebaseError directly for a collision.
            // Normal flow routes through resolveAuthError which populates providers.
            return .accountExistsWithDifferentCredential(
                email: error.userInfo[AuthErrorUserInfoEmailKey] as? String,
                existingProviders: []
            )
        case .operationNotAllowed:
            return .providerNotEnabled
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
