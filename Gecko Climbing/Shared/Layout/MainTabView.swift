import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var selectedTab: AppTab = .feed
    @State private var previousTab: AppTab = .feed
    @State private var sessionKey = UUID()
    @State private var sessionListRefreshToken = UUID()
    @State private var feedRefreshToken = UUID()
    @State private var logClimbCount = 0
    @State private var finishTrigger = UUID()

    var body: some View {
        ZStack {
            HomeView(refreshToken: feedRefreshToken)
                .opacity(selectedTab == .feed ? 1 : 0)
                .allowsHitTesting(selectedTab == .feed)

            SessionListView(refreshToken: sessionListRefreshToken)
                .opacity(selectedTab == .sessions ? 1 : 0)
                .allowsHitTesting(selectedTab == .sessions)

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
            .opacity(selectedTab == .log ? 1 : 0)
            .allowsHitTesting(selectedTab == .log)

            SocialView()
                .opacity(selectedTab == .social ? 1 : 0)
                .allowsHitTesting(selectedTab == .social)

            ProfileView()
                .opacity(selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(selectedTab == .profile)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
        .onChange(of: selectedTab) { oldTab, newTab in
            previousTab = oldTab
            if newTab == .feed {
                feedRefreshToken = UUID()
            }
        }
    }

}
