import Foundation

/// Tunables and constants for the feed algorithm. Centralized here so ranking
/// and demo-filtering rules don't drift between repository, view-model, and UI.
enum FeedConfig {
    // MARK: - Demo accounts

    /// User IDs whose posts and profiles are excluded from public feeds.
    /// Posts authored by these accounts will never appear in Discover and will
    /// be filtered from Following on top of the standard follow graph (defense
    /// in depth — even if a user manually follows a demo account, the demo's
    /// content stays out of the feed).
    ///
    /// TODO: Fill in the Firebase Auth UID for `demo@trygecko.app` before launch.
    /// Find it by signing in as the demo account and printing
    /// `Auth.auth().currentUser?.uid`, or pull it from the Firebase console.
    static let demoUserIds: Set<String> = [
        // "<demo-uid-here>"
    ]

    // MARK: - Discover query

    /// Posts older than this are not eligible for Discover.
    static let discoverWindowDays: Int = 30

    /// Hard cap on Discover results before client-side ranking.
    static let discoverFetchLimit: Int = 100

    // MARK: - Ranking weights (Discover)

    /// Engagement multiplier — comments are worth 2x a like in the score.
    static let engagementCommentMultiplier: Double = 2.0

    /// Hours-old is divided by this; bigger = slower decay.
    /// 36 hours ≈ 1 score-point of decay per 1.5 days.
    static let timeDecayHours: Double = 36

    /// Bonus for posts at one of the viewer's home gyms.
    static let gymMatchBonus: Double = 1.5

    /// Bonus when post.topGrade is within +/- this many V-grades of the
    /// viewer's highest. "Climbers want to see climbing they aspire to or
    /// recently conquered" — V12 monkeys are noise to a V2 climber.
    static let gradeProximityWindow: Int = 1
    static let gradeProximityBonus: Double = 0.5

    // MARK: - "Your gym" detection

    /// Number of most-frequented gyms to treat as the viewer's "home gyms"
    /// when no manual override is set.
    static let homeGymTopN: Int = 3
}
