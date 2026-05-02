import SwiftUI

/// Top-of-feed segmented control. "Following" / "Discover" with an animated
/// underline indicator that morphs between tabs via `matchedGeometryEffect`.
///
/// Design choices:
/// - Underline (3pt, brand primary) instead of the iOS pill segmented look —
///   feels more like a content-first social feed (Beli, Letterboxd, X) than
///   a settings screen.
/// - Active label is bolder + primary-tinted; inactive is secondary. Subtle,
///   so the indicator does the heavy lifting.
/// - Optional unread dot on the inactive label ("hasFreshDiscover") acts as
///   a quiet nudge — the user notices, opens the rail, sees fresh content.
/// - Header sits *under* the nav bar (which holds the Gecko logo) and stays
///   pinned while the feed scrolls. A hairline divider separates it from
///   the cards below for visual stability.
struct FeedRailSwitcher: View {
    @Binding var selection: FeedRail
    var hasFreshDiscover: Bool = false

    @Namespace private var underlineNamespace

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 32) {
                ForEach(FeedRail.allCases, id: \.self) { rail in
                    railButton(rail)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
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
            withAnimation(.geckoSnappy) {
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
                .animation(.geckoSnappy, value: showDot)

                ZStack(alignment: .center) {
                    // Reserve the indicator's vertical space on every tab so
                    // labels don't shift when switching.
                    Color.clear.frame(height: 3)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.geckoPrimary)
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                            .matchedGeometryEffect(id: "rail-underline", in: underlineNamespace)
                    }
                }
            }
            .padding(.vertical, 8)
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
