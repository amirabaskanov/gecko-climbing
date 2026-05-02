import SwiftUI

/// Top-of-feed segmented control. "Following" / "Discover" with an animated
/// underline indicator that morphs between tabs via `matchedGeometryEffect`.
///
/// Design choices:
/// - Underline (2pt, soft brand-mint) — same shape language as a classic
///   underlined tab bar but at a fraction of the visual weight, so the
///   indicator settles in rather than shouting.
/// - Active label is bolder + primary-tinted; inactive is the secondary
///   text color. Subtle, so the indicator does the heavy lifting.
/// - Optional unread dot on the inactive label ("hasFreshDiscover") acts as
///   a quiet nudge — the user notices, opens the rail, sees fresh content.
/// - Tabs split the header 50/50 with the underline sized to match the
///   label width, so the indicator reads as a clean accent under the type
///   rather than a stripe stretching the full half-width.
struct FeedRailSwitcher: View {
    @Binding var selection: FeedRail
    var hasFreshDiscover: Bool = false

    @Namespace private var underlineNamespace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(FeedRail.allCases, id: \.self) { rail in
                    railButton(rail)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 0)

            Divider()
                .overlay(Color.geckoDivider)
        }
        .background(Color.geckoBackground)
    }

    private func railButton(_ rail: FeedRail) -> some View {
        let isSelected = selection == rail
        let showDot = !isSelected && rail == .discover && hasFreshDiscover

        return Button {
            guard selection != rail else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                selection = rail
            }
            AnalyticsService.capture(.feedRailSwitched, properties: ["rail": rail.rawValue])
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Text(rail.title)
                        .font(.system(size: 16, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.primary : Color.geckoSecondaryText)
                        .padding(.horizontal, 2)

                    if showDot {
                        Circle()
                            .fill(Color.geckoPrimary)
                            .frame(width: 6, height: 6)
                            .offset(x: 8, y: -1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showDot)

                ZStack(alignment: .center) {
                    // Reserve the indicator's vertical space on every tab so
                    // labels don't shift when switching.
                    Color.clear.frame(height: 2)

                    if isSelected {
                        // Soft brand-mint accent — same shape language as
                        // the original primary-green bar, but at a fraction
                        // of the visual weight so the indicator settles in
                        // rather than shouting.
                        Capsule(style: .continuous)
                            .fill(Color.geckoMint)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "rail-underline", in: underlineNamespace)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rail.title)\(showDot ? ", new posts available" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
