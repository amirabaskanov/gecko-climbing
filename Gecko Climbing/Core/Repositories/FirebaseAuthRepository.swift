import Foundation
import FirebaseAuth
import GoogleSignIn

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
            throw mapFirebaseError(error)
        }
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    func signOut() throws {
        do {
            try Auth.auth().signOut()
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        do {
            try await Auth.auth().signIn(with: credential)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        do {
            try await Auth.auth().signIn(with: credential)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
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

    private func mapFirebaseError(_ error: NSError) -> AuthError {
        switch AuthErrorCode(rawValue: error.code) {
        case .wrongPassword, .invalidCredential, .userNotFound:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .networkError:
            return .networkError
        default:
            return .networkError
        }
    }
}
