import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    @State private var floatOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            GeckoLogoView(size: 56, color: .geckoPrimary.opacity(0.6))
                .offset(y: floatOffset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        floatOffset = -8
                    }
                }

            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.geckoPrimary)
                        .clipShape(Capsule())
                }
                .bouncePress()
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
