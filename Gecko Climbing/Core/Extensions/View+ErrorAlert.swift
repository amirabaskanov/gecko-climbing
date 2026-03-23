import SwiftUI

// MARK: - String + Identifiable (for .sheet(item:) with String IDs)

extension String: @retroactive Identifiable {
    public var id: String { self }
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
        self
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    func cardStyleElevated(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.geckoPrimary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
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
