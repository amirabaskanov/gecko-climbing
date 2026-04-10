import CryptoKit
import Foundation

enum AppleSignInHelper {
    /// Generates a cryptographically random nonce string. Throws
    /// `AuthError.nonceGenerationFailed` if the underlying CSPRNG call fails
    /// (a rare condition that should propagate as a normal error rather than
    /// crash the app).
    static func randomNonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            throw AuthError.nonceGenerationFailed(Int(result))
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Returns the SHA256 hash of the input string as a lowercase hex string.
    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
