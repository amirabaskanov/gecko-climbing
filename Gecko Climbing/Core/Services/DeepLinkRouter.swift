import Foundation
import Observation

enum NotificationRoute: Hashable, Sendable {
    case post(id: String)
    case profile(userId: String)
    case session(id: String)
    case comment(postId: String, commentId: String)
    case weeklyRecap
}

extension NotificationRoute {
    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo["route"] as? String else { return nil }
        let parts = raw.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard let kind = parts.first else { return nil }
        switch kind {
        case "post":
            guard parts.count == 2 else { return nil }
            self = .post(id: String(parts[1]))
        case "profile":
            guard parts.count == 2 else { return nil }
            self = .profile(userId: String(parts[1]))
        case "session":
            guard parts.count == 2 else { return nil }
            self = .session(id: String(parts[1]))
        case "comment":
            guard parts.count == 3 else { return nil }
            self = .comment(postId: String(parts[1]), commentId: String(parts[2]))
        case "weekly-recap":
            self = .weeklyRecap
        default:
            return nil
        }
    }
}

@MainActor
@Observable
final class DeepLinkRouter {
    @MainActor static weak var shared: DeepLinkRouter?

    var pendingRoute: NotificationRoute?

    init() {}

    func setPendingRoute(_ route: NotificationRoute) {
        pendingRoute = route
    }
}
