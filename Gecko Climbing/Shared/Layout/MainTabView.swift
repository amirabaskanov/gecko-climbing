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
            guard !UserDefaults.standard.bool(forKey: seenKey) else { return }
            let sessions = (try? await appEnv.sessionRepository.fetchSessions(for: uid)) ?? []
            if sessions.isEmpty {
                showOnboarding = true
            } else {
                UserDefaults.standard.set(true, forKey: seenKey)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                let uid = appEnv.authRepository.currentUserId
                if !uid.isEmpty {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding.\(uid)")
                }
                showOnboarding = false
                selectedTab = .log
            }
        }
        .sheet(isPresented: $showNotificationPrompt) {
            NotificationPrePromptView()
        }
        #if DEBUG
        // DEBUG ONLY — force-present the first-run guide from Settings for QA.
        // Remove this, the Settings row, and the Notification.Name below to ship.
        .onReceive(NotificationCenter.default.publisher(for: .debugReplayOnboarding)) { _ in
            showOnboarding = true
        }
        #endif
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

// MARK: - First-run onboarding
//
// Lean 4-step first-run guide shown once to brand-new climbers (see the
// `hasSeenOnboarding` gate above). Teaches the two things a newcomer can't
// guess — V-grades and the flash/sent/attempt outcomes — personalizes their
// starting grade, and drops them into the Log tab. Colocated with its presenter
// so it ships without a project-file edit. Pages advance via the button only
// (no swipe), so the grade barrel's horizontal scroll doesn't fight a pager.

private struct OnboardingView: View {
    /// Called on finish or skip; the caller persists the seen-flag, dismisses,
    /// and routes to the Log tab.
    var onFinish: () -> Void

    /// Same key the logger reads for its default grade, so "pick your level"
    /// personalizes the very first climb they log.
    @AppStorage("lastSelectedGrade") private var lastSelectedGrade = "V5"

    @State private var page = 0
    @State private var pickedGrade = "V3"
    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch page {
                case 0: welcomePage
                case 1: gradePage
                case 2: outcomesPage
                default: readyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(page)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            footer
        }
        .animation(.geckoSpring, value: page)
        .background(Color.geckoBackground.ignoresSafeArea())
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Spacer()
            if page < lastPage {
                Button("Skip") { finish() }
                    .font(.subheadline.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.geckoSecondaryText)
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0...lastPage, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.geckoPrimary : Color.geckoDivider)
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.geckoSnappy, value: page)

            Button {
                advance()
            } label: {
                Text(page == lastPage ? "Start climbing" : "Continue")
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.geckoPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .bouncePress()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private func advance() {
        if page < lastPage {
            withAnimation(.geckoSpring) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        lastSelectedGrade = pickedGrade
        onFinish()
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            GeckoLogoView(size: 104, color: .geckoPrimary)
            VStack(spacing: 12) {
                Text("Welcome to Gecko")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Track every climb.\nWatch yourself get stronger.")
                    .font(.title3)
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.geckoSecondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var gradePage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)
            pageHeadline("What's your level?",
                         "Scroll to the grade you usually climb — we'll start you there.")
            GradeBarrelView(selectedGrade: $pickedGrade, grades: VGrade.standard)
            Text("V0 is beginner and the scale climbs from there. Not sure? Pick anything — you can change it on every climb.")
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundStyle(Color.geckoSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var outcomesPage: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)
            pageHeadline("How'd the climb go?", "Three ways to log each climb.")
            VStack(spacing: 14) {
                outcomeRow("bolt.fill", .geckoFlashGold, "Flash", "Sent it first try")
                outcomeRow("checkmark", .geckoSentGreen, "Sent", "Sent it in 2+ tries")
                outcomeRow("arrow.counterclockwise", .geckoAttemptBlue, "Attempt", "Still working on it")
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var readyPage: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.geckoPrimary)
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.geckoPrimary.opacity(0.4), radius: 16, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            pageHeadline("Log your first climb",
                         "Tap the green + any time to start a session. Pick a grade, tap an outcome — that's it.")
            Spacer()
            Spacer()
        }
    }

    // MARK: Bits

    private func pageHeadline(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(Color.geckoSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private func outcomeRow(_ icon: String, _ color: Color, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.geckoSecondaryText)
            }
            Spacer()
        }
        .padding(14)
        .cardStyle()
    }
}

#if DEBUG
// DEBUG ONLY — remove before shipping (see the Settings "Replay guide" row).
extension Notification.Name {
    static let debugReplayOnboarding = Notification.Name("debugReplayOnboarding")
}
#endif
