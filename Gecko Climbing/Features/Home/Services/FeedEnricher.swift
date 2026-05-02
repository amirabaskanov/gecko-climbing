import Foundation

/// Derives contextual `FeedBadge`s for a post based on the post itself, the
/// post-author's profile, and the viewer's context. No network calls — all
/// signals come from data already in memory after the feed query.
///
/// Heuristics intentionally err on the side of fewer badges. A card with
/// three competing chips reads as cluttered; one well-chosen chip reads as
/// "this app understands me."
enum FeedEnricher {
    /// Compute badges for a single post.
    /// - Parameters:
    ///   - post: The candidate post.
    ///   - author: The post-author's user profile, looked up by `post.userId`.
    ///     Pass `nil` if unavailable; PR detection is skipped in that case.
    ///   - viewer: The local viewer's context.
    static func badges(for post: PostModel, author: UserModel?, viewer: FeedViewerContext) -> [FeedBadge] {
        var result: [FeedBadge] = []

        // PR — post.topGrade matches the author's all-time max and is a real
        // grade (≥ V1). We avoid celebrating V0 because every newcomer's
        // first session would be a "PR" otherwise.
        if let author,
           post.topGradeNumeric >= 1,
           post.topGradeNumeric == author.highestGradeNumeric {
            result.append(.personalBest(grade: post.topGrade))
        }

        // Your gym — case-insensitive match against the viewer's home set.
        // Skip when the post is the viewer's own post; saying "your gym" on
        // your own post is noise.
        if post.userId != viewer.userId,
           !viewer.homeGyms.isEmpty,
           !post.gymName.isEmpty,
           viewer.homeGyms.contains(post.gymName.lowercased()) {
            result.append(.yourGym(name: post.gymName))
        }

        // Your level — the post's top grade is within ±1 of the viewer's
        // current best. Mutually exclusive with `personalBest` to avoid a
        // double-celebration on the same chip row.
        if !result.contains(where: { if case .personalBest = $0 { return true } else { return false } }),
           post.userId != viewer.userId,
           viewer.highestGradeNumeric >= 0,
           post.topGradeNumeric >= 0,
           abs(post.topGradeNumeric - viewer.highestGradeNumeric) <= FeedConfig.gradeProximityWindow {
            result.append(.yourLevel(grade: post.topGrade))
        }

        return result.sorted { $0.priority < $1.priority }
    }
}
