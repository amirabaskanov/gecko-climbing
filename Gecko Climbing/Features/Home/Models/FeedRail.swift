import Foundation

/// Which rail of the dual-feed Home tab the user is currently viewing.
/// `following` is friend-centric (chronological from people you follow + you).
/// `discover` is global recent posts ranked client-side by `FeedRanker`.
enum FeedRail: String, Hashable, CaseIterable {
    case following
    case discover

    var title: String {
        switch self {
        case .following: return "Following"
        case .discover: return "Discover"
        }
    }
}
