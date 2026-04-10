import Foundation

struct NotificationPrefs: Codable, Equatable, Sendable {
    var social: Bool
    var friends: Bool
    var reminders: Bool
    var friendPosts: Bool

    static let `default` = NotificationPrefs(social: true, friends: true, reminders: true, friendPosts: false)
}

extension NotificationPrefs {
    init(dictionary: [String: Any]?) {
        guard let dictionary else {
            self = .default
            return
        }
        self.social = dictionary["social"] as? Bool ?? true
        self.friends = dictionary["friends"] as? Bool ?? true
        self.reminders = dictionary["reminders"] as? Bool ?? true
        self.friendPosts = dictionary["friendPosts"] as? Bool ?? false
    }

    var asDictionary: [String: Any] {
        [
            "social": social,
            "friends": friends,
            "reminders": reminders,
            "friendPosts": friendPosts
        ]
    }
}
