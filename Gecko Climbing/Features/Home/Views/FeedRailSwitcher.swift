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
            // Equal-width tabs so the two labels split the screen 50/50 and
            // read as a balanced pair, the way Beli / Letterboxd / X handle
            // a two-tab segmented control. Each `railButton` claims half the
            // header and centers its label within that half.
            HStack(spacing: 0) {
                ForEach(FeedRail.allCases, id: \.self) { rail in
                    railButton(rail)
                        .frame(maxWidth: .infinity)
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
            // Soft eased spring so the underline glides instead of snapping —
            // the rail switch should feel like a small visual settle, not a
            // selection click.
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                selection = rail
            }
            AnalyticsService.capture(.feedRailSwitched, properties: ["rail": rail.rawValue])
        } label: {
            // Label + underline stack is content-sized (no infinity frames
            // here) so the underline width matches the label width — the
            // outer button claims the full half-width for hit area.
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Text(rail.title)
                        // Active is full-weight on the foreground color;
                        // inactive is the same weight but in tertiary so the
                        // contrast comes from opacity rather than a bright
                        // accent. Reads as quiet and intentional.
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.6))
                        .padding(.horizontal, 2)

                    if showDot {
                        Circle()
                            .fill(Color.geckoPrimary)
                            .frame(width: 5, height: 5)
                            .offset(x: 7, y: -1)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showDot)

                ZStack(alignment: .center) {
                    // Reserve the indicator's vertical space on every tab so
                    // labels don't shift when switching.
                    Color.clear.frame(height: 2)

                    if isSelected {
                        // Thin, foreground-tinted bar — same color as the
                        // active label, so the indicator reads as part of
                        // the type rather than a brand-color stripe.
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.85))
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "rail-underline", in: underlineNamespace)
                    }
                }
            }
            .padding(.vertical, 10)
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
