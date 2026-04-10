import Foundation

struct NotificationPrefs: Codable, Equatable, Sendable {
    var social: Bool
    var friends: Bool
    var reminders: Bool

    static let `default` = NotificationPrefs(social: true, friends: true, reminders: true)
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
    }

    var asDictionary: [String: Any] {
        [
            "social": social,
            "friends": friends,
            "reminders": reminders
        ]
    }
}
