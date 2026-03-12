import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var selectedTab: AppTab = .feed
    @State private var previousTab: AppTab = .feed
    @State private var sessionKey = UUID()
    @State private var sessionListRefreshToken = UUID()
    @State private var logClimbCount = 0
    @State private var finishTrigger = UUID()

    var body: some View {
        Group {
            switch selectedTab {
            case .feed:
                HomeView()
            case .sessions:
                SessionListView(refreshToken: sessionListRefreshToken)
            case .log:
                NewSessionView(
                    climbCount: $logClimbCount,
                    finishTrigger: finishTrigger,
                    onSessionSaved: { _ in
                        sessionListRefreshToken = UUID()
                        logClimbCount = 0
                        selectedTab = .sessions
                        sessionKey = UUID()
                    },
                    onCancel: {
                        logClimbCount = 0
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
            CustomTabBar(
                selectedTab: $selectedTab,
                logClimbCount: logClimbCount,
                onLogTap: {
                    if selectedTab != .log {
                        previousTab = selectedTab
                    }
                    selectedTab = .log
                },
                onFinishTap: {
                    if logClimbCount > 0 {
                        finishTrigger = UUID()
                    } else {
                        // No climbs — cancel back
                        logClimbCount = 0
                        selectedTab = previousTab
                        sessionKey = UUID()
                    }
                }
            )
        }
    }
}
