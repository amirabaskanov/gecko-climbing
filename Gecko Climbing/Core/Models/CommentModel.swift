import Foundation

struct CommentModel: Identifiable, Equatable {
    let id: String
    let postId: String
    let userId: String
    let userDisplayName: String
    let userProfileImageURL: String
    let text: String
    let createdAt: Date
    let parentId: String?
    let replyToDisplayName: String?
    let mentions: [String] // usernames mentioned with @

    init(id: String = UUID().uuidString,
         postId: String,
         userId: String,
         userDisplayName: String = "",
         userProfileImageURL: String = "",
         text: String,
         createdAt: Date = Date(),
         parentId: String? = nil,
         replyToDisplayName: String? = nil,
         mentions: [String] = []) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.userProfileImageURL = userProfileImageURL
        self.text = text
        self.createdAt = createdAt
        self.parentId = parentId
        self.replyToDisplayName = replyToDisplayName
        self.mentions = mentions
    }

    var isReply: Bool { parentId != nil }
}

/// A top-level comment with its replies grouped together
struct CommentThread: Identifiable {
    let id: String
    let root: CommentModel
    var replies: [CommentModel]

    init(root: CommentModel, replies: [CommentModel] = []) {
        self.id = root.id
        self.root = root
        self.replies = replies
    }
}
