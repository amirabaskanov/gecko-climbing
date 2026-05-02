import SwiftUI

/// Top-of-feed segmented control. "Following" / "Discover" rendered as a
/// sliding-pill picker — a soft cream tray containing a white card pill that
/// glides between options.
///
/// Why this design over a classic underlined tab bar:
/// - The whole feed page leans on cards-and-pills (V-grade barrels, climb
///   pills, the Suggested Climbers carousel). A pill picker lands in the
///   same visual vocabulary, where an underlined tab bar would have read
///   as "borrowed from a different app."
/// - The motion is a settle, not a stripe. There's no accent bar racing
///   across the screen on every switch.
/// - The active pill is the indicator. No second accent element to fight
///   the active label for attention.
///
/// Implementation:
/// - Outer Capsule tray uses `geckoInputBackground` so it reads as a quiet
///   recessed tray on the cream main background, slightly tinted in dark.
/// - Active pill is `geckoCard` with a soft drop shadow, slid via
///   `matchedGeometryEffect` for a hardware-accelerated morph.
/// - Tray width is contained (max ~280pt) and centered, so the picker feels
///   like a control instead of taking over the full header.
struct FeedRailSwitcher: View {
    @Binding var selection: FeedRail
    var hasFreshDiscover: Bool = false

    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FeedRail.allCases, id: \.self) { rail in
                railOption(rail)
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.geckoInputBackground)
        )
        .frame(maxWidth: 280)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(Color.geckoBackground)
    }

    private func railOption(_ rail: FeedRail) -> some View {
        let isSelected = selection == rail
        let showDot = !isSelected && rail == .discover && hasFreshDiscover

        return Button {
            guard selection != rail else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selection = rail
            }
            AnalyticsService.capture(.feedRailSwitched, properties: ["rail": rail.rawValue])
        } label: {
            HStack(spacing: 6) {
                Text(rail.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                if showDot {
                    Circle()
                        .fill(Color.geckoPrimary)
                        .frame(width: 5, height: 5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(activePillBackground(isSelected: isSelected))
            .contentShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: showDot)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rail.title)\(showDot ? ", new posts available" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func activePillBackground(isSelected: Bool) -> some View {
        if isSelected {
            Capsule(style: .continuous)
                .fill(Color.geckoCard)
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                .matchedGeometryEffect(id: "rail-pill", in: pillNamespace)
        }
    }
}

#if DEBUG
private struct FeedRailSwitcherPreviewWrapper: View {
    @State var rail: FeedRail = .following
    var fresh: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            FeedRailSwitcher(selection: $rail, hasFreshDiscover: fresh)
            Spacer()
            Text("Selected: \(rail.title)")
                .padding()
        }
        .background(Color.geckoBackground)
    }
}

#Preview("Switcher — light") {
    FeedRailSwitcherPreviewWrapper(fresh: true)
        .preferredColorScheme(.light)
}

#Preview("Switcher — dark") {
    FeedRailSwitcherPreviewWrapper(fresh: true)
        .preferredColorScheme(.dark)
}
#endif
