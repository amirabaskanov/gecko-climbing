import Foundation

/// Tunables and constants for the feed algorithm. Centralized here so ranking
/// and demo-filtering rules don't drift between repository, view-model, and UI.
enum FeedConfig {
    // MARK: - Demo accounts

    /// User IDs whose posts and profiles are excluded from public feeds.
    /// Posts authored by these accounts will never appear in Discover and will
    /// be filtered from Following on top of the standard follow graph (defense
    /// in depth — even if a user manually follows a demo account, the demo's
    /// content stays out of the feed). Currently the `demo@trygecko.app`
    /// App Review account.
    static let demoUserIds: Set<String> = [
        "9lo0nSmjSoQz5Mt739CKceZmJxM2"
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

    // MARK: - Suggestion scoring (SuggestionEngine)

    /// Points per mutual follow ("followed by people you follow") — the
    /// strongest signal. Capped so one hyper-connected friend circle can't
    /// drown out every other signal.
    static let suggestionMutualWeight: Double = 10
    static let suggestionMutualCap: Int = 3

    /// Candidate already follows the viewer but isn't followed back.
    static let suggestionFollowsYouWeight: Double = 8

    /// Candidate climbs at (posted from, or home-gym matches) one of the
    /// viewer's home gyms.
    static let suggestionGymWeight: Double = 5

    /// Candidate's top grade within ±`gradeProximityWindow` of the viewer's.
    static let suggestionGradePeerWeight: Double = 3

    /// Candidate pool size requested from `suggestedClimbers` before scoring.
    static let suggestionCandidatePoolLimit: Int = 30

    /// Max followed users whose own following lists are fetched for the
    /// friends-of-friends signal — bounds Firestore reads per load.
    static let suggestionFriendFanOutLimit: Int = 15
}
