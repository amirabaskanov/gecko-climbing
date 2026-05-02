import Foundation

/// Snapshot of the local viewer used by `FeedRanker` and `FeedEnricher` to
/// score posts and derive contextual badges. Purely value-typed so it can be
/// safely passed across actor boundaries during ranking.
struct FeedViewerContext: Equatable {
    /// The viewer's own UID. Posts authored by the viewer are still shown but
    /// never get badges that wouldn't make sense ("Your gym" on your own post).
    let userId: String

    /// The viewer's highest sent grade (numeric, V0 = 0). `-1` if none yet.
    let highestGradeNumeric: Int

    /// Gyms the viewer is treated as belonging to. Manually-set
    /// `homeGymOverride` wins; otherwise the top N most-frequented gyms from
    /// session history. Compared case-insensitively.
    let homeGyms: Set<String>

    static let empty = FeedViewerContext(userId: "", highestGradeNumeric: -1, homeGyms: [])

    /// Builds a viewer context from the user's profile + session history.
    /// `homeGyms` is the manual override (a single gym) when set, otherwise
    /// the top `FeedConfig.homeGymTopN` gyms by frequency across recent
    /// sessions. Comparison happens against a case-insensitive set so we
    /// don't miss "Movement Denver" vs "movement denver".
    static func make(user: UserModel, sessionGymNames: [String]) -> FeedViewerContext {
        let gyms: Set<String>
        if let override = user.homeGymOverride, !override.isEmpty {
            gyms = [override.lowercased()]
        } else {
            // Frequency-sort the gym names.
            var counts: [String: Int] = [:]
            for name in sessionGymNames where !name.isEmpty {
                counts[name.lowercased(), default: 0] += 1
            }
            let topGyms = counts
                .sorted { $0.value > $1.value }
                .prefix(FeedConfig.homeGymTopN)
                .map(\.key)
            gyms = Set(topGyms)
        }
        return FeedViewerContext(
            userId: user.uid,
            highestGradeNumeric: user.highestGradeNumeric,
            homeGyms: gyms
        )
    }
}
