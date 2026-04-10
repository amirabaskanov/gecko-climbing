import Foundation

// MARK: - Protocol
protocol AuthRepositoryProtocol: AnyObject {
    var currentUserId: String { get }
    var isAuthenticated: Bool { get }
    var currentUserDisplayName: String { get }
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, username: String, displayName: String) async throws
    func signOut() throws
    func signInWithGoogle(idToken: String, accessToken: String) async throws
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws
    func addAuthStateListener(_ listener: @escaping (Bool) -> Void)
    func removeAuthStateListener()
}

// MARK: - Mock Implementation
final class MockAuthRepository: AuthRepositoryProtocol, @unchecked Sendable {
    private(set) var currentUserId: String = ""
    private(set) var isAuthenticated: Bool = false
    private(set) var currentUserDisplayName: String = ""
    private var stateListener: ((Bool) -> Void)?

    private var mockUsers: [String: (email: String, password: String, displayName: String)] = [
        "user1@test.com": ("user1@test.com", "password123", "Alex Stone"),
        "user2@test.com": ("user2@test.com", "password123", "Sam Rocks")
    ]

    init() {}

    #if DEBUG
    /// Preview-only: start out signed in as a fake user so previews land on the
    /// authenticated UI without needing to run through sign-in flow first.
    static func previewAuthenticated(userId: String = "preview_user",
                                     displayName: String = "Preview Climber") -> MockAuthRepository {
        let repo = MockAuthRepository()
        repo.currentUserId = userId
        repo.currentUserDisplayName = displayName
        repo.isAuthenticated = true
        return repo
    }
    #endif

    func signIn(email: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard let user = mockUsers[email], user.password == password else {
            throw AuthError.invalidCredentials
        }
        currentUserId = email.replacingOccurrences(of: "@test.com", with: "")
        currentUserDisplayName = user.displayName
        isAuthenticated = true
        stateListener?(true)
    }

    func signUp(email: String, password: String, username: String, displayName: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard !mockUsers.keys.contains(email) else {
            throw AuthError.emailAlreadyInUse
        }
        mockUsers[email] = (email, password, displayName)
        currentUserId = email.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
        currentUserDisplayName = displayName
        isAuthenticated = true
        stateListener?(true)
    }

    func signOut() throws {
        currentUserId = ""
        currentUserDisplayName = ""
        isAuthenticated = false
        stateListener?(false)
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        currentUserId = "google_mock_user"
        currentUserDisplayName = "Google User"
        isAuthenticated = true
        stateListener?(true)
    }

    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        currentUserId = "apple_mock_user"
        let given = fullName?.givenName ?? "Apple"
        let family = fullName?.familyName ?? "User"
        currentUserDisplayName = "\(given) \(family)"
        isAuthenticated = true
        stateListener?(true)
    }

    func addAuthStateListener(_ listener: @escaping (Bool) -> Void) {
        stateListener = listener
        listener(isAuthenticated)
    }

    func removeAuthStateListener() {
        stateListener = nil
    }
}

// MARK: - Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyInUse
    case networkError
    case cancelled
    case tokenMissing
    /// Email is already registered via one or more other providers. `existingProviders`
    /// holds Firebase provider IDs ("apple.com", "google.com", "password") so the UI can
    /// tell the user exactly which button to tap. Empty if email enumeration protection
    /// is on and we couldn't look them up.
    case accountExistsWithDifferentCredential(email: String?, existingProviders: [String])
    case providerNotEnabled
    case appleAuthorizationFailed(String)
    case nonceGenerationFailed(Int)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password."
        case .emailAlreadyInUse: return "An account with this email already exists."
        case .networkError: return "Network error. Please try again."
        case .cancelled: return "Sign-in was cancelled."
        case .tokenMissing: return "Apple didn't return a sign-in token. Please try again."
        case .accountExistsWithDifferentCredential(_, let providers):
            return Self.accountCollisionMessage(providers: providers)
        case .providerNotEnabled:
            return "Apple Sign-In isn't enabled for this app yet. Please try Google or email."
        case .appleAuthorizationFailed(let message):
            return "Apple Sign-In failed: \(message)"
        case .nonceGenerationFailed:
            return "Couldn't start Apple Sign-In securely. Please try again."
        case .unknown(let message):
            return message
        }
    }

    private static func accountCollisionMessage(providers: [String]) -> String {
        let known = providers.compactMap(providerLabel(for:))
        switch known.count {
        case 0:
            return "You already have an account with this email. Please sign in with your original method."
        case 1:
            let (name, action) = known[0]
            return "You already registered with \(name). \(action)"
        default:
            let names = known.map(\.0).joined(separator: " or ")
            return "You already have an account with this email. Sign in with \(names)."
        }
    }

    private static func providerLabel(for providerId: String) -> (String, String)? {
        switch providerId {
        case "apple.com":
            return ("Apple", "Tap 'Sign in with Apple' above to continue.")
        case "google.com":
            return ("Google", "Tap 'Continue with Google' above to continue.")
        case "password", "emailLink":
            return ("email and password", "Sign in with your email and password below.")
        default:
            return nil
        }
    }
}
