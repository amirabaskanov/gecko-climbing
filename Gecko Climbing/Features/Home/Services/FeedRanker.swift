import Foundation

/// Pure scoring logic for the Discover rail. No I/O, no state — given a
/// candidate post and the viewer's context, returns a numeric score; `rank`
/// returns posts sorted descending by score.
///
/// Following stays chronological (handled directly in the view-model) so this
/// only applies to Discover. The formula is intentionally simple and tunable
/// from `FeedConfig`:
///
///     score = log(1 + likes + 2*comments)            // engagement
///           − hoursOld / FeedConfig.timeDecayHours    // recency decay
///           + (gymMatch ? gymMatchBonus : 0)          // local relevance
///           + (gradeProximity ? gradeProximityBonus : 0)
///
enum FeedRanker {
    static func score(_ post: PostModel, for viewer: FeedViewerContext, now: Date = Date()) -> Double {
        let engagement = log(1 + Double(post.likesCount) + FeedConfig.engagementCommentMultiplier * Double(post.commentsCount))
        let hoursOld = max(0, now.timeIntervalSince(post.createdAt) / 3600)
        let timeDecay = hoursOld / FeedConfig.timeDecayHours

        var bonus: Double = 0
        if !viewer.homeGyms.isEmpty,
           !post.gymName.isEmpty,
           viewer.homeGyms.contains(post.gymName.trimmedGymName.lowercased()) {
            bonus += FeedConfig.gymMatchBonus
        }
        if viewer.highestGradeNumeric >= 0,
           post.topGradeNumeric >= 0,
           abs(post.topGradeNumeric - viewer.highestGradeNumeric) <= FeedConfig.gradeProximityWindow {
            bonus += FeedConfig.gradeProximityBonus
        }

        return engagement - timeDecay + bonus
    }

    static func rank(_ posts: [PostModel], for viewer: FeedViewerContext, now: Date = Date()) -> [PostModel] {
        // Score once, then sort. Avoids re-evaluating the formula per
        // comparator call in the sort closure.
        let scored = posts.map { (post: $0, score: score($0, for: viewer, now: now)) }
        return scored
            .sorted { $0.score > $1.score }
            .map(\.post)
    }
}
