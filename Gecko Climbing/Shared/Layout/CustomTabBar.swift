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
    let onLogTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                if tab == .log {
                    logButton
                } else {
                    tabButton(tab)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? Color.geckoGreen : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button(action: onLogTap) {
            ZStack {
                Circle()
                    .fill(Color.geckoGreen)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.geckoGreen.opacity(0.35), radius: 6, x: 0, y: 3)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(y: -14)
        }
        .frame(maxWidth: .infinity)
    }
}
