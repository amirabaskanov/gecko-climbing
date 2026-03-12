import SwiftUI

// MARK: - Gecko Logo View

/// Brand gecko logo — traced from the Anymark brand asset.
/// Uses SVG from asset catalog with template rendering for dynamic tinting.
struct GeckoLogoView: View {
    var size: CGFloat = 64
    var color: Color = .geckoPrimary
    var showWordmark: Bool = false
    var wordmarkColor: Color = .primary

    var body: some View {
        if showWordmark {
            HStack(spacing: size * 0.15) {
                geckoIcon
                Text("gecko")
                    .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
                    .foregroundStyle(wordmarkColor)
            }
        } else {
            geckoIcon
        }
    }

    private var geckoIcon: some View {
        Image("GeckoLogo")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

#Preview("Logo Variants") {
    VStack(spacing: 40) {
        GeckoLogoView(size: 120, color: .geckoPrimary)
        GeckoLogoView(size: 60, color: .geckoPrimary, showWordmark: true)
        GeckoLogoView(size: 40, color: .white, showWordmark: true, wordmarkColor: .white)
            .padding()
            .background(Color.geckoPrimary, in: RoundedRectangle(cornerRadius: 16))
    }
    .padding()
}
