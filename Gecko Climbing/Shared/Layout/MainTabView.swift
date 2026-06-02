import SwiftUI

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var selectedTab: AppTab = .feed
    @State private var previousTab: AppTab = .feed
    @State private var sessionKey = UUID()
    @State private var sessionListRefreshToken = UUID()
    @State private var feedRefreshToken = UUID()
    @State private var logClimbCount = 0
    @State private var finishTrigger = UUID()
    @State private var homeRouter = TabRouter<HomeRoute>()
    @State private var sessionRouter = TabRouter<SessionRoute>()
    @State private var socialRouter = TabRouter<SocialRoute>()
    @State private var profileRouter = TabRouter<ProfileRoute>()

    var body: some View {
        ZStack {
            HomeView(router: homeRouter, refreshToken: feedRefreshToken)
                .opacity(selectedTab == .feed ? 1 : 0)
                .allowsHitTesting(selectedTab == .feed)

            SessionListView(
                refreshToken: sessionListRefreshToken,
                onStartSession: {
                    if selectedTab != .log {
                        previousTab = selectedTab
                    }
                    selectedTab = .log
                },
                router: sessionRouter
            )
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

            SocialView(router: socialRouter)
                .opacity(selectedTab == .social ? 1 : 0)
                .allowsHitTesting(selectedTab == .social)

            ProfileView(router: profileRouter)
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
        .onChange(of: deepLinkRouter.pendingRoute) { _, newRoute in
            guard let newRoute else { return }
            handleNotificationRoute(newRoute)
        }
    }

    private func handleNotificationRoute(_ route: NotificationRoute) {
        defer { deepLinkRouter.pendingRoute = nil }
        switch route {
        case .profile(let userId):
            selectedTab = .social
            socialRouter.setPath([.friendProfile(uid: userId)])
        case .session(let id):
            selectedTab = .sessions
            sessionRouter.setPath([.sessionDetail(sessionId: id)])
        case .weeklyRecap:
            selectedTab = .profile
            profileRouter.setPath([.fullStats, .weekInReview])
        case .post(let id):
            selectedTab = .feed
            homeRouter.setPath([.postDetail(postId: id)])
        case .comment(let postId, _):
            // Land on the post; its comment thread is one tap away. The
            // specific comment id isn't deep-linked yet.
            selectedTab = .feed
            homeRouter.setPath([.postDetail(postId: postId)])
        }
    }
}
