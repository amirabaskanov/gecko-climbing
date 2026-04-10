import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import PostHog

/// Result of attempting to bring up the app's persistence + DI graph at launch.
private enum AppBootstrap {
    case ready(
        modelContainer: ModelContainer,
        appEnv: AppEnvironment,
        authViewModel: AuthViewModel,
        notificationService: NotificationService,
        deepLinkRouter: DeepLinkRouter
    )
    case failed(Error)
}

@main
struct GeckoClimbingApp: App {
    @UIApplicationDelegateAdaptor(GeckoAppDelegate.self) private var appDelegate
    private let bootstrap: AppBootstrap

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        AnalyticsService.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        do {
            let container = try ModelContainer(
                for: SessionModel.self,
                     ClimbModel.self,
                     UserModel.self,
                     PostModel.self
            )
            let env = AppEnvironment()
            let auth = AuthViewModel(authRepository: env.authRepository)
            let service = NotificationService(
                userRepository: env.userRepository,
                authRepository: env.authRepository
            )
            let router = DeepLinkRouter()
            NotificationService.shared = service
            DeepLinkRouter.shared = router
            bootstrap = .ready(
                modelContainer: container,
                appEnv: env,
                authViewModel: auth,
                notificationService: service,
                deepLinkRouter: router
            )
        } catch {
            bootstrap = .failed(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(modelContainer, env, auth, service, router):
                AppRootView()
                    .environment(env)
                    .environment(auth)
                    .environment(service)
                    .environment(router)
                    .modelContainer(modelContainer)
                    .tint(Color.geckoPrimary)
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
            case let .failed(error):
                StorageErrorView(error: error)
                    .tint(Color.geckoPrimary)
            }
        }
    }
}

/// Fallback view shown when the SwiftData `ModelContainer` cannot be created
/// (e.g. an unrecoverable migration failure). The user sees a clear message
/// instead of the app silently dying at launch.
struct StorageErrorView: View {
    let error: Error

    var body: some View {
        ZStack {
            Color.geckoBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color.geckoPrimary)

                Text("Storage Error")
                    .font(.system(.title, design: .rounded).weight(.bold))

                Text("Gecko couldn't open its local database. Please restart the app, and if the problem persists, reinstall to recover.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text(error.localizedDescription)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct AppRootView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.geckoBackground.ignoresSafeArea()

            if authViewModel.isAuthenticated {
                MainTabView()
                    .environment(appEnv)
                    .environment(authViewModel)
                    .transition(.opacity)
            } else {
                AuthRootView()
                    .environment(appEnv)
                    .environment(authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, authViewModel.isAuthenticated else { return }
            Task { await notificationService.refreshScheduledNotifications() }
        }
    }
}
