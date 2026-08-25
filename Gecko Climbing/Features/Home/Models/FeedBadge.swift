import SwiftUI

/// A small contextual signal rendered on a feed card to surface why this post
/// matters *to the viewer*. These are derived purely from data the viewer and
/// post-author already have on file (no extra writes, no new server schema).
///
/// Order in `allCases` is the priority order — when more than one badge fires
/// for a single post the cards show the most rare/celebratory ones first.
enum FeedBadge: Hashable {
    /// The post-author hit their all-time highest grade in this session.
    /// Equivalent to "personal best" — the most celebratory badge.
    case personalBest(grade: String)
    /// The post is at one of the viewer's most-frequented gyms (or their
    /// manual home-gym override).
    case yourGym(name: String)
    /// The post's top grade is within ±1 of the viewer's all-time highest.
    /// Climbers care most about climbing they're aspiring to or just conquered.
    case yourLevel(grade: String)

    var label: String {
        switch self {
        case .personalBest(let g):  return "\(GradeDisplaySettings.shared.label(forStored: g)) personal best"
        case .yourGym(let n):       return n
        case .yourLevel:            return "Your level"
        }
    }

    var icon: String {
        switch self {
        case .personalBest: return "trophy.fill"
        case .yourGym:      return "mappin.circle.fill"
        case .yourLevel:    return "scope"
        }
    }

    var tint: Color {
        switch self {
        case .personalBest: return .geckoFlashGold
        case .yourGym:      return .geckoPrimary
        case .yourLevel:    return .geckoOrange
        }
    }

    /// Sort key — lower wins (renders leftmost). Mirrors priority: a PR
    /// always upstages a same-gym ping, which upstages a same-grade ping.
    var priority: Int {
        switch self {
        case .personalBest: return 0
        case .yourGym:      return 1
        case .yourLevel:    return 2
        }
    }
}
