import Foundation
import Observation

@Observable @MainActor
final class CommentsViewModel {
    var comments: [CommentModel] = []
    var newCommentText = ""
    var isLoading = false
    var isSending = false
    var error: Error?

    // Reply state
    var replyingTo: CommentModel?

    // @mention state
    var mentionQuery: String?
    var mentionSuggestions: [UserModel] = []
    private var followingCache: [UserModel] = []

    let postId: String
    private let postRepository: any PostRepositoryProtocol
    private let userRepository: any UserRepositoryProtocol
    let userId: String
    let userDisplayName: String
    let userProfileImageURL: String

    var onCommentCountChanged: ((Int) -> Void)?

    init(postId: String,
         postRepository: any PostRepositoryProtocol,
         userRepository: any UserRepositoryProtocol,
         userId: String,
         userDisplayName: String,
         userProfileImageURL: String) {
        self.postId = postId
        self.postRepository = postRepository
        self.userRepository = userRepository
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.userProfileImageURL = userProfileImageURL
    }

    // MARK: - Computed

    var canSend: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var threads: [CommentThread] {
        let topLevel = comments.filter { $0.parentId == nil }
        return topLevel.map { root in
            let replies = comments
                .filter { $0.parentId == root.id }
                .sorted { $0.createdAt < $1.createdAt }
            return CommentThread(root: root, replies: replies)
        }
    }

    var totalCount: Int { comments.count }

    var inputPlaceholder: String {
        if let reply = replyingTo {
            return "Reply to \(reply.userDisplayName)..."
        }
        return "Add a comment..."
    }

    func isOwnComment(_ comment: CommentModel) -> Bool {
        comment.userId == userId
    }

    // MARK: - Load

    func loadComments() async {
        isLoading = true
        do {
            comments = try await postRepository.fetchComments(postId: postId)
        } catch {
            self.error = error
        }
        isLoading = false

        // Preload following list for @mentions
        if followingCache.isEmpty {
            followingCache = (try? await userRepository.fetchFollowing(uid: userId)) ?? []
        }
    }

    // MARK: - Reply

    func startReply(to comment: CommentModel) {
        // Always reply to the root comment (not a reply-to-reply)
        let rootComment = comment.parentId == nil ? comment : comments.first { $0.id == comment.parentId } ?? comment
        replyingTo = rootComment
        newCommentText = "@\(comment.userDisplayName) "
    }

    func cancelReply() {
        replyingTo = nil
        newCommentText = ""
    }

    // MARK: - Send

    func sendComment() async {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true
        let detectedMentions = extractMentions(from: trimmed)
        let comment = CommentModel(
            postId: postId,
            userId: userId,
            userDisplayName: userDisplayName,
            userProfileImageURL: userProfileImageURL,
            text: trimmed,
            parentId: replyingTo?.id,
            replyToDisplayName: replyingTo?.userDisplayName,
            mentions: detectedMentions
        )

        do {
            try await postRepository.addComment(comment)
            comments.append(comment)
            newCommentText = ""
            replyingTo = nil
            mentionQuery = nil
            mentionSuggestions = []
            onCommentCountChanged?(totalCount)
            AnalyticsService.capture(.commentAdded)
        } catch {
            self.error = error
        }
        isSending = false
    }

    // MARK: - Delete

    func deleteComment(_ comment: CommentModel) async {
        guard comment.userId == userId else { return }

        // Collect IDs to delete: the comment itself + all its replies if it's a root
        var idsToDelete = [comment.id]
        if comment.parentId == nil {
            idsToDelete += comments.filter { $0.parentId == comment.id }.map(\.id)
        }

        do {
            for id in idsToDelete {
                try await postRepository.deleteComment(postId: postId, commentId: id)
            }
            comments.removeAll { idsToDelete.contains($0.id) }
            onCommentCountChanged?(totalCount)
            AnalyticsService.capture(.commentDeleted)
        } catch {
            self.error = error
        }
    }

    // MARK: - @Mentions

    func onTextChanged(_ text: String) {
        newCommentText = text
        if let query = activeMentionQuery(in: text) {
            mentionQuery = query
            mentionSuggestions = followingCache.filter { user in
                user.displayName.localizedStandardContains(query) ||
                user.username.localizedStandardContains(query)
            }
        } else {
            mentionQuery = nil
            mentionSuggestions = []
        }
    }

    func insertMention(_ user: UserModel) {
        guard let query = mentionQuery else { return }
        // Replace the @query with @displayName
        let searchToken = "@\(query)"
        if let range = newCommentText.range(of: searchToken, options: .backwards) {
            newCommentText.replaceSubrange(range, with: "@\(user.displayName) ")
        }
        mentionQuery = nil
        mentionSuggestions = []
    }

    // MARK: - Private Helpers

    /// Extracts display names from @mentions in the text
    private func extractMentions(from text: String) -> [String] {
        var mentions: [String] = []
        let knownNames = Set(followingCache.map(\.displayName))

        for name in knownNames {
            if text.contains("@\(name)") {
                mentions.append(name)
            }
        }
        return mentions
    }

    /// Returns the active @mention query if the cursor is mid-mention
    private func activeMentionQuery(in text: String) -> String? {
        guard let lastAt = text.lastIndex(of: "@") else { return nil }
        let afterAt = text[text.index(after: lastAt)...]

        // If there's a newline after @, it's not a mention
        if afterAt.contains("\n") { return nil }

        let query = String(afterAt)
        // Only show suggestions for 1+ character queries
        guard !query.isEmpty else { return nil }
        return query
    }
}
