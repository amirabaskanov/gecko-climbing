import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main
struct GeckoClimbingApp: App {
    let modelContainer: ModelContainer
    @State private var appEnv: AppEnvironment
    @State private var authViewModel: AuthViewModel

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
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
            let env = AppEnvironment(modelContext: container.mainContext)
            let auth = AuthViewModel(authRepository: env.authRepository)
            _appEnv = State(initialValue: env)
            _authViewModel = State(initialValue: auth)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appEnv)
                .environment(authViewModel)
                .modelContainer(modelContainer)
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
