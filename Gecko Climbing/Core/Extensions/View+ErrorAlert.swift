import SwiftUI

// MARK: - String + Identifiable (for .sheet(item:) with String IDs)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - CardStyleModifier

/// Shared card chrome. Surface hierarchy rule: list cards get a hairline
/// border and NO shadow (flat, editorial); the elevated card — at most one
/// per screen (stats hero, personal-best moment) — gets the screen's only
/// shadow and a larger radius. Radius scale 10 / 14 / 22 encodes depth.
private struct CardStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .background(Color.geckoCard)
            .clipShape(shape)
            .overlay(shape.stroke(elevated ? Color.clear : Color.geckoDivider, lineWidth: 1))
            .shadow(
                color: .black.opacity(elevated ? 0.06 : 0),
                radius: elevated ? 16 : 0,
                x: 0, y: elevated ? 4 : 0
            )
    }
}

// MARK: - BounceButtonStyle

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.geckoSpring, value: configuration.isPressed)
    }
}

// MARK: - User-Facing Error Copy

/// Maps raw errors to copy that is safe to show users. Backend SDK messages
/// can embed console URLs and the Firebase project id (e.g. Firestore's
/// "The query requires an index. You can create it here: https://…/project/…")
/// — those must never reach an alert. Domains are matched as string literals
/// so this file stays free of Firebase imports.
enum UserFacingError {
    private static let firestoreDomain = "FIRFirestoreErrorDomain"
    private static let authDomain = "FIRAuthErrorDomain"

    /// Substrings that mark a message as internal. Anything matching falls
    /// back to generic copy no matter which error produced it.
    private static let leakyFragments = [
        "http", "firebaseapp", "googleapis", "firestore.google", "gecko-climbing", "index"
    ]

    static func message(for error: Error) -> String {
        let nsError = error as NSError

        switch nsError.domain {
        case firestoreDomain:
            return firestoreMessage(code: nsError.code)
        case authDomain:
            return authMessage(code: nsError.code)
        case NSURLErrorDomain:
            return "You appear to be offline. Check your connection and try again."
        default:
            // Local app errors (LocalizedError types) carry curated copy —
            // pass it through unless it smells like an internal message.
            let candidate = error.localizedDescription
            return isSafe(candidate) ? candidate : genericMessage
        }
    }

    static var genericMessage: String {
        "Something went wrong. Please try again."
    }

    private static func isSafe(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return !leakyFragments.contains { lowered.contains($0) }
    }

    private static func firestoreMessage(code: Int) -> String {
        // Codes mirror FirestoreErrorCode (gRPC status codes).
        switch code {
        case 7:  return "You don't have permission to do that."
        case 5:  return "That content is no longer available."
        case 4, 14: return "Couldn't reach the server. Check your connection and try again."
        case 8:  return "We're a bit overloaded right now — try again in a minute."
        case 9:  return "Something's not ready on our end — try again in a minute."
        case 16: return "Please sign in again to continue."
        default: return genericMessage
        }
    }

    private static func authMessage(code: Int) -> String {
        // Codes mirror AuthErrorCode.
        switch code {
        case 17004, 17009: return "That email or password doesn't look right."
        case 17008: return "That doesn't look like a valid email address."
        case 17011: return "No account found with that email."
        case 17007: return "An account with that email already exists."
        case 17026: return "Please choose a stronger password (at least 6 characters)."
        case 17010: return "Too many attempts — please wait a moment and try again."
        case 17020: return "You appear to be offline. Check your connection and try again."
        default: return genericMessage
        }
    }
}

// MARK: - View Extensions

extension View {
    func errorAlert(error: Binding<Error?>) -> some View {
        alert("Something went wrong", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("OK") { error.wrappedValue = nil }
        } message: {
            if let error = error.wrappedValue {
                Text(alertMessage(for: error))
            }
        }
    }

    func errorAlert(error: Binding<Error?>, retryAction: @escaping () -> Void) -> some View {
        alert("Something went wrong", isPresented: Binding(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Button("Retry") {
                error.wrappedValue = nil
                retryAction()
            }
            Button("Dismiss", role: .cancel) { error.wrappedValue = nil }
        } message: {
            if let error = error.wrappedValue {
                Text(alertMessage(for: error))
            }
        }
    }

    private func alertMessage(for error: Error) -> String {
        #if DEBUG
        return UserFacingError.message(for: error) + "\n\n[debug] " + error.localizedDescription
        #else
        return UserFacingError.message(for: error)
        #endif
    }

    func cardStyle(cornerRadius: CGFloat = 14) -> some View {
        modifier(CardStyleModifier(cornerRadius: cornerRadius, elevated: false))
    }

    func cardStyleElevated(cornerRadius: CGFloat = 22) -> some View {
        modifier(CardStyleModifier(cornerRadius: cornerRadius, elevated: true))
    }

    func bouncePress() -> some View {
        self.buttonStyle(BounceButtonStyle())
    }

    /// Extra bottom padding so content isn't hidden behind the floating tab bar
    func tabBarPadding() -> some View {
        self.safeAreaPadding(.bottom, 16)
    }

    func staggeredAppear(index: Int, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .geckoSpring.delay(Double(index) * 0.05),
                value: appeared
            )
    }
}
