import TipKit

/// Central TipKit setup + shared tip state.
enum AppTips {
    /// Flips true once the first-run guide has been completed, skipped, or
    /// deemed unnecessary (established users). Tips are rule-gated on this so
    /// they never stack on top of onboarding.
    @Parameter static var onboardingComplete: Bool = false

    static func configure() {
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }
}

/// Teaches the center tab button's morph — the one interaction in the app
/// nobody can guess from looking at it: + starts a session; while logging it
/// becomes a checkmark (finish) or an X (cancel with nothing logged).
struct LogButtonTip: Tip {
    var title: Text {
        Text("One button runs your session")
    }

    var message: Text? {
        Text("Tap + to start logging. While a session is open it turns into a checkmark to finish, or an X to cancel if you haven't logged anything yet.")
    }

    var image: Image? {
        Image(systemName: "plus.circle.fill")
    }

    var rules: [Rule] {
        #Rule(AppTips.$onboardingComplete) { $0 == true }
    }

    var options: [any TipOption] {
        MaxDisplayCount(1)
    }
}
