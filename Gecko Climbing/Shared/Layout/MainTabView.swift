import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var selectedTab: AppTab = .feed
    @State private var previousTab: AppTab = .feed
    @State private var sessionKey = UUID()
    @State private var sessionListRefreshToken = UUID()

    var body: some View {
        Group {
            switch selectedTab {
            case .feed:
                HomeView()
            case .sessions:
                SessionListView(refreshToken: sessionListRefreshToken)
            case .log:
                NewSessionView(
                    onSessionSaved: { _ in
                        sessionListRefreshToken = UUID()
                        selectedTab = .sessions
                        sessionKey = UUID()
                    },
                    onCancel: {
                        selectedTab = previousTab
                        sessionKey = UUID()
                    }
                )
                .id(sessionKey)
            case .social:
                SocialView()
            case .profile:
                ProfileView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab) {
                if selectedTab != .log {
                    previousTab = selectedTab
                }
                selectedTab = .log
            }
        }
    }
}
