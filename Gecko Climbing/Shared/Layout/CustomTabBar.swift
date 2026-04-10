import SwiftUI

enum AppTab: Int, CaseIterable {
    case feed, sessions, log, social, profile

    var label: String {
        switch self {
        case .feed:     return "Feed"
        case .sessions: return "Sessions"
        case .log:      return "Log"
        case .social:   return "Friends"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .feed:     return "house.fill"
        case .sessions: return "figure.climbing"
        case .log:      return "plus"
        case .social:   return "person.2.fill"
        case .profile:  return "person.crop.circle.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var logClimbCount: Int = 0
    let onLogTap: () -> Void
    var onFinishTap: (() -> Void)?

    private var isOnLogTab: Bool { selectedTab == .log }
    private var hasClimbs: Bool { logClimbCount > 0 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                if tab == .log {
                    centerButton
                } else {
                    tabButton(tab)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -2)
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: -1)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.geckoSnappy) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                Text(tab.label)
                    .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.geckoPrimary : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.geckoSnappy, value: selectedTab)
    }

    private var centerButton: some View {
        Button {
            if isOnLogTab {
                onFinishTap?()
            } else {
                onLogTap()
            }
        } label: {
            // TimelineView drives the pulse from wall-clock time so it pauses
            // automatically when the tab bar is off-screen, unlike a
            // `withAnimation(.repeatForever)` loop, which keeps running until
            // the view is torn down regardless of `.task` cancellation.
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // 4s period, eased between 0 and 1 via cosine.
                let pulse = (1 - cos(t * .pi / 2.0)) / 2
                let pulseShadowOpacity = 0.2 + 0.2 * pulse
                let pulseShadowRadius = 6.0 + 4.0 * pulse

                ZStack {
                    Circle()
                        .fill(centerButtonColor)
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: centerButtonColor.opacity(
                                isOnLogTab && !hasClimbs ? 0.15 : (isOnLogTab ? 0.2 : pulseShadowOpacity)
                            ),
                            radius: isOnLogTab ? 6 : pulseShadowRadius,
                            x: 0, y: 3
                        )

                    Image(systemName: centerButtonIcon)
                        .font(.system(size: isOnLogTab ? 22 : 26, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .offset(y: -18)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(centerButtonAccessibilityLabel)
        .animation(.geckoSpring, value: isOnLogTab)
        .animation(.geckoSpring, value: hasClimbs)
    }

    private var centerButtonAccessibilityLabel: String {
        if isOnLogTab {
            return hasClimbs ? "Finish session" : "Cancel logging"
        }
        return "Log a climb"
    }

    private var centerButtonIcon: String {
        if isOnLogTab {
            return hasClimbs ? "checkmark" : "xmark"
        }
        return "plus"
    }

    private var centerButtonColor: Color {
        return Color.geckoPrimary
    }
}
