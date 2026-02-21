import Foundation

enum HomeRoute: Hashable {
    case postDetail(postId: String)
    case friendProfile(uid: String)
}

enum SessionRoute: Hashable {
    case sessionDetail(sessionId: String)
}

enum SocialRoute: Hashable {
    case friendProfile(uid: String)
    case followersList(uid: String)
    case followingList(uid: String)
}

enum StatsRoute: Hashable {
    case profile
}
