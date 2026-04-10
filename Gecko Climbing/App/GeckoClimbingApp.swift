import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn
import PostHog

@main
struct GeckoClimbingApp: App {
    @UIApplicationDelegateAdaptor(GeckoAppDelegate.self) private var appDelegate
    let modelContainer: ModelContainer
    @State private var appEnv: AppEnvironment
    @State private var authViewModel: AuthViewModel
    @State private var notificationService: NotificationService
    @State private var deepLinkRouter: DeepLinkRouter

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
            modelContainer = container
            let env = AppEnvironment()
            let auth = AuthViewModel(authRepository: env.authRepository)
            let service = NotificationService(
                userRepository: env.userRepository,
                authRepository: env.authRepository
            )
            let router = DeepLinkRouter()
            NotificationService.shared = service
            DeepLinkRouter.shared = router
            _appEnv = State(initialValue: env)
            _authViewModel = State(initialValue: auth)
            _notificationService = State(initialValue: service)
            _deepLinkRouter = State(initialValue: router)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appEnv)
                .environment(authViewModel)
                .environment(notificationService)
                .environment(deepLinkRouter)
                .modelContainer(modelContainer)
                .tint(Color.geckoPrimary)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

struct AppRootView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel

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
    }
}
