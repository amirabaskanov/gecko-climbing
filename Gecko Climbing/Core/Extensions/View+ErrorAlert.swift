import SwiftUI

// MARK: - String + Identifiable (for .sheet(item:) with String IDs)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - CardStyleModifier

/// Shared card chrome that adapts shadows + border to the current color scheme.
/// In light mode we use soft black shadows for lift; in dark mode shadows are
/// invisible, so we lean on a subtle border + slightly stronger shadow to keep
/// the card distinct from the background.
private struct CardStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    let elevated: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark
        let shadowOpacity1 = isDark ? 0.35 : (elevated ? 0.04 : 0.04)
        let shadowOpacity2 = isDark ? 0.45 : (elevated ? 0.08 : 0.06)
        let strokeOpacity = isDark ? 0.18 : (elevated ? 0.10 : 0.06)
        let strokeColor = isDark ? Color.white.opacity(strokeOpacity)
                                 : Color.geckoPrimary.opacity(strokeOpacity)

        return content
            .background(Color.geckoCard)
            .clipShape(shape)
            .overlay(shape.stroke(strokeColor, lineWidth: 1))
            .shadow(color: .black.opacity(shadowOpacity1),
                    radius: elevated ? 2 : 1, x: 0, y: 1)
            .shadow(color: .black.opacity(shadowOpacity2),
                    radius: elevated ? 12 : 8, x: 0, y: elevated ? 6 : 4)
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
                Text(error.localizedDescription)
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
                Text(error.localizedDescription)
            }
        }
    }

    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardStyleModifier(cornerRadius: cornerRadius, elevated: false))
    }

    func cardStyleElevated(cornerRadius: CGFloat = 16) -> some View {
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
