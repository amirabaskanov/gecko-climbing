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
    @State private var showOnboarding = false
    @State private var showNotificationPrompt = false
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
                    maybePromptForNotifications()
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
        .task {
            // One-time per user: merge any gym-name spelling variants on their
            // existing sessions (and linked posts) to a single canonical form.
            // Runs off the main path; the flag makes it a no-op on later launches.
            let uid = appEnv.authRepository.currentUserId
            guard !uid.isEmpty else { return }
            let migratedKey = "gymNameMigration.v1.\(uid)"
            guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
            if await appEnv.sessionRepository.normalizeGymNames(for: uid) {
                UserDefaults.standard.set(true, forKey: migratedKey)
            }
        }
        .task {
            // Show the first-run guide once, only to climbers who haven't logged
            // anything yet (i.e. genuinely new). Established users get flagged as
            // seen so it never interrupts them.
            let uid = appEnv.authRepository.currentUserId
            guard !uid.isEmpty else { return }
            let seenKey = "hasSeenOnboarding.\(uid)"
            guard !UserDefaults.standard.bool(forKey: seenKey) else {
                AppTips.onboardingComplete = true
                return
            }
            do {
                let sessions = try await appEnv.sessionRepository.fetchSessions(for: uid)
                if sessions.isEmpty {
                    showOnboarding = true
                } else {
                    UserDefaults.standard.set(true, forKey: seenKey)
                    AppTips.onboardingComplete = true
                }
            } catch {
                // Fetch failed (offline / transient backend error): this may be
                // a returning user, so don't show the guide — and don't burn
                // the flag, so a genuinely new user gets it next launch.
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                let uid = appEnv.authRepository.currentUserId
                if !uid.isEmpty {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding.\(uid)")
                }
                AppTips.onboardingComplete = true
                showOnboarding = false
                // Remount the logger so it picks up the grade chosen in the
                // guide and starts its timer fresh — NewSessionView has been
                // mounted (and timing) since app launch in the tab ZStack, so
                // without this the "we'll start you there" promise breaks for
                // the user's very first session.
                logClimbCount = 0
                sessionKey = UUID()
                selectedTab = .log
            }
        }
        .sheet(isPresented: $showNotificationPrompt) {
            NotificationPrePromptView()
        }
        // Settings → Support → "Replay the Guide" re-presents the cover,
        // bypassing the once-per-user gate.
        .onReceive(NotificationCenter.default.publisher(for: .replayOnboarding)) { _ in
            showOnboarding = true
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

    private func maybePromptForNotifications() {
        // First saved session is the ideal moment to ask for notifications —
        // they've just felt the value. Soft pre-prompt, shown once per user.
        let uid = appEnv.authRepository.currentUserId
        guard !uid.isEmpty else { return }
        let key = "hasSeenNotifPrompt.\(uid)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        showNotificationPrompt = true
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

