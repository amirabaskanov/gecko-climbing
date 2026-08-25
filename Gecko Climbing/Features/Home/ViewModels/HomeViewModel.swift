import Foundation
import Observation

@Observable @MainActor
final class HomeViewModel {
    // MARK: - Rails

    /// Currently visible rail. Default is decided once per session by
    /// `pickInitialRail()` based on whether the user has followed anyone yet.
    var currentRail: FeedRail = .following

    /// Posts from people the viewer follows + their own (chronological).
    /// Demo accounts are filtered out at both the query layer and here as
    /// belt-and-suspenders.
    var followingPosts: [PostModel] = []

    /// Recent global posts ranked by `FeedRanker`.
    var discoverPosts: [PostModel] = []

    /// Scored follow suggestions for the empty Following state and the
    /// Discover rail. Built by `SuggestionLoader` AFTER the follow graph
    /// resolves so already-followed users never appear; each entry carries
    /// the reason it was suggested.
    var suggestions: [ScoredSuggestion] = []

    /// Users-only projection of `suggestions` for views that don't need
    /// scores or reasons.
    var suggestedClimbers: [UserModel] { suggestions.map(\.user) }

    /// IDs of users the viewer follows. Used by the carousel to flip the
    /// follow button to "Following" optimistically without re-querying.
    private(set) var followingIds: Set<String> = []

    /// Cached map of post-author profiles, keyed by uid. Populated lazily so
    /// `FeedEnricher` can derive the "personal best" badge (which needs the
    /// author's all-time `highestGradeNumeric`).
    private(set) var authorProfiles: [String: UserModel] = [:]

    /// Viewer context (highest grade, home gyms) used for ranking + badges.
    /// Recomputed on `loadFeed()` from the user profile and recent sessions.
    private(set) var viewerContext: FeedViewerContext = .empty

    // MARK: - UI state

    var isLoadingFollowing = false
    var isLoadingDiscover = false
    var error: Error?

    // MARK: - Dependencies

    let postRepository: any PostRepositoryProtocol
    let userRepository: any UserRepositoryProtocol
    let sessionRepository: any SessionRepositoryProtocol
    let feedbackRepository: any FeedbackRepositoryProtocol
    let userId: String
    var userDisplayName: String = ""
    var userProfileImageURL: String = ""

    /// User IDs the viewer has blocked. Refreshed from the user doc on every
    /// `loadFeed()` and on optimistic `blockUser(uid:)` calls. Posts and
    /// comments authored by these users are filtered out client-side from
    /// both rails before the views see them.
    private(set) var blockedUserIds: Set<String> = []

    private var backfillTask: Task<Void, Never>?
    private var initialRailDecided = false

    init(
        postRepository: any PostRepositoryProtocol,
        userRepository: any UserRepositoryProtocol,
        sessionRepository: any SessionRepositoryProtocol,
        feedbackRepository: any FeedbackRepositoryProtocol,
        userId: String
    ) {
        self.postRepository = postRepository
        self.userRepository = userRepository
        self.sessionRepository = sessionRepository
        self.feedbackRepository = feedbackRepository
        self.userId = userId
    }

    // MARK: - Comments hook (unchanged)

    func updateCommentCount(postId: String, count: Int) {
        if let idx = followingPosts.firstIndex(where: { $0.postId == postId }) {
            followingPosts[idx].commentsCount = count
        }
        if let idx = discoverPosts.firstIndex(where: { $0.postId == postId }) {
            discoverPosts[idx].commentsCount = count
        }
    }

    // MARK: - Loading

    /// Loads everything needed for both rails plus the viewer context. Safe
    /// to call repeatedly (pull-to-refresh, sign-in change). Context, rails,
    /// and follow graph load concurrently; suggestions run after, because
    /// they need the resolved follow graph, viewer profile, and Discover
    /// posts as ranking inputs.
    func loadFeed() async {
        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        isLoadingDiscover = true
        error = nil
        backfillTask?.cancel()

        // Build viewer context from profile + recent sessions in parallel
        // with the post fetches; even if profile lookup fails we still want
        // to render whatever posts came back.
        async let contextTask: (context: FeedViewerContext, user: UserModel?) = makeViewerContext()
        async let followingTask: [PostModel] = fetchFollowingSafe()
        async let discoverTask: [PostModel] = fetchDiscoverSafe()
        async let followingIdsTask: Set<String> = fetchFollowingIds()

        let (context, viewer) = await contextTask
        let following = await followingTask
        let rawDiscover = await discoverTask
        let ids = await followingIdsTask

        viewerContext = context
        followingIds = ids
        // Pull the latest block list out of the viewer-context fetch so the
        // filter is applied before any post hits the UI.
        blockedUserIds = context.blockedUserIds
        followingPosts = following.filter { !blockedUserIds.contains($0.userId) }
        let filteredDiscover = rawDiscover.filter { !blockedUserIds.contains($0.userId) }
        discoverPosts = FeedRanker.rank(filteredDiscover, for: context)

        // Deliberately serialized after the follow graph: fetching in the
        // same parallel batch read an empty `followingIds` on first load and
        // suggested people the viewer already follows.
        let scored = await SuggestionLoader().load(
            viewerUid: userId,
            viewerUser: viewer,
            followingIds: ids,
            discoverPosts: rawDiscover,
            viewerGyms: context.homeGyms,
            userRepository: userRepository,
            limit: 10
        )
        suggestions = scored.filter { !blockedUserIds.contains($0.user.uid) }

        // Resolve author profiles lazily so badge derivation works even when
        // the profile cache is cold. We only fetch profiles we don't already
        // have to keep this cheap.
        await hydrateAuthorProfiles(for: following + rawDiscover)

        if !initialRailDecided {
            currentRail = pickInitialRail()
            initialRailDecided = true
        }

        AnalyticsService.capture(.feedLoaded, properties: [
            "following_count": following.count,
            "discover_count": rawDiscover.count
        ])

        backfillTask = makeBackfillTask(for: following)

        isLoadingFollowing = false
        isLoadingDiscover = false
    }

    /// Cheap reload of just one rail — used on rail switch when content
    /// might be stale but we don't want to re-fetch everything.
    func refreshCurrentRail() async {
        switch currentRail {
        case .following:
            isLoadingFollowing = true
            followingPosts = await fetchFollowingSafe()
            isLoadingFollowing = false
        case .discover:
            isLoadingDiscover = true
            let raw = await fetchDiscoverSafe()
            discoverPosts = FeedRanker.rank(raw, for: viewerContext)
            isLoadingDiscover = false
        }
    }

    // MARK: - Likes

    func toggleLike(_ post: PostModel) async {
        // Find the post in whichever rail owns it.
        let inFollowing = followingPosts.firstIndex(where: { $0.postId == post.postId })
        let inDiscover = discoverPosts.firstIndex(where: { $0.postId == post.postId })

        let wasLiked = post.isLikedByCurrentUser

        // Optimistic update — flip both rails so the UI is consistent if the
        // same post appears (it shouldn't, but be safe).
        if let i = inFollowing {
            followingPosts[i].isLikedByCurrentUser = !wasLiked
            followingPosts[i].likesCount += wasLiked ? -1 : 1
        }
        if let i = inDiscover {
            discoverPosts[i].isLikedByCurrentUser = !wasLiked
            discoverPosts[i].likesCount += wasLiked ? -1 : 1
        }

        do {
            if wasLiked {
                try await postRepository.unlikePost(post.postId, userId: userId)
                AnalyticsService.capture(.postUnliked)
            } else {
                try await postRepository.likePost(post.postId, userId: userId)
                AnalyticsService.capture(.postLiked)
            }
        } catch {
            // Revert
            if let i = inFollowing {
                followingPosts[i].isLikedByCurrentUser = wasLiked
                followingPosts[i].likesCount += wasLiked ? 1 : -1
            }
            if let i = inDiscover {
                discoverPosts[i].isLikedByCurrentUser = wasLiked
                discoverPosts[i].likesCount += wasLiked ? 1 : -1
            }
            self.error = error
        }
    }

    // MARK: - Follow (used by suggestions carousel)

    func follow(_ user: UserModel) async {
        guard !followingIds.contains(user.uid) else { return }
        followingIds.insert(user.uid)
        do {
            try await userRepository.follow(targetUID: user.uid)
            AnalyticsService.capture(.userFollowed)
        } catch {
            followingIds.remove(user.uid)
            self.error = error
        }
    }

    func unfollow(_ user: UserModel) async {
        guard followingIds.contains(user.uid) else { return }
        followingIds.remove(user.uid)
        do {
            try await userRepository.unfollow(targetUID: user.uid)
            AnalyticsService.capture(.userUnfollowed)
        } catch {
            followingIds.insert(user.uid)
            self.error = error
        }
    }

    // MARK: - Moderation (App Store Review Guideline 1.2)

    /// Submit a report for the given post. Fire-and-forget: the user gets no
    /// confirmation toast — the dialog dismissing is the feedback. Errors
    /// surface through the standard `error` channel.
    func reportPost(_ post: PostModel, reason: ReportModel.Reason) async {
        let report = ReportModel(
            reporterUserId: userId,
            targetType: .post,
            targetId: post.postId,
            targetPostId: post.postId,
            targetAuthorId: post.userId,
            reason: reason
        )
        do {
            try await feedbackRepository.submitReport(report)
            AnalyticsService.capture(.postReported, properties: ["reason": reason.rawValue])
        } catch {
            self.error = error
        }
    }

    /// Block the user with `uid`. Optimistically removes their posts from
    /// both rails so the action feels immediate; on failure the posts come
    /// back via the next `loadFeed()`.
    func blockUser(uid: String) async {
        guard !blockedUserIds.contains(uid) else { return }
        let removedFollowing = followingPosts.filter { $0.userId == uid }
        let removedDiscover = discoverPosts.filter { $0.userId == uid }
        blockedUserIds.insert(uid)
        followingPosts.removeAll { $0.userId == uid }
        discoverPosts.removeAll { $0.userId == uid }

        do {
            try await userRepository.blockUser(uid)
            AnalyticsService.capture(.userBlocked)
        } catch {
            // Roll back the optimistic UI on failure.
            blockedUserIds.remove(uid)
            followingPosts.append(contentsOf: removedFollowing)
            discoverPosts.append(contentsOf: removedDiscover)
            self.error = error
        }
    }

    // MARK: - Badges (called from view)

    func badges(for post: PostModel) -> [FeedBadge] {
        FeedEnricher.badges(
            for: post,
            author: authorProfiles[post.userId],
            viewer: viewerContext
        )
    }

    // MARK: - Suggestions (called from view)

    /// Reason line for a suggested user ("Followed by Phuc"), nil if the uid
    /// isn't currently suggested.
    func suggestionReason(for uid: String) -> String? {
        suggestions.first { $0.user.uid == uid }?.reason.label
    }

    // MARK: - Private helpers

    private func pickInitialRail() -> FeedRail {
        // New users land on Discover so they always have content. Returning
        // users with at least one followed person who has posted recently
        // start on Following.
        let hasFreshFollowingContent = !followingPosts.isEmpty
        return hasFreshFollowingContent ? .following : .discover
    }

    private func makeViewerContext() async -> (context: FeedViewerContext, user: UserModel?) {
        // Profile + sessions concurrently; fall back to empty context on any
        // failure so badges/ranking just become no-ops instead of crashing.
        // The raw user model rides along for the suggestion loader (grade +
        // block list) so it doesn't have to re-fetch the profile.
        async let userTask: UserModel? = try? userRepository.fetchCurrentUser()
        async let sessionsTask: [SessionModel] = (try? sessionRepository.fetchSessions(for: userId)) ?? []

        guard let user = await userTask else { return (.empty, nil) }
        let sessions = await sessionsTask
        return (FeedViewerContext.make(user: user, sessionGymNames: sessions.map(\.gymName)), user)
    }

    private func fetchFollowingSafe() async -> [PostModel] {
        do {
            let raw = try await postRepository.fetchFeed(for: userId)
            return raw.filter { !FeedConfig.demoUserIds.contains($0.userId) }
        } catch {
            self.error = error
            return []
        }
    }

    private func fetchDiscoverSafe() async -> [PostModel] {
        do {
            let raw = try await postRepository.fetchDiscover(for: userId)
            return raw.filter { !FeedConfig.demoUserIds.contains($0.userId) }
        } catch {
            // Discover failures don't block Following — Discover just renders
            // empty until next refresh.
            #if DEBUG
            print("⚠️ Discover load failed: \(error)")
            #endif
            return []
        }
    }

    private func fetchFollowingIds() async -> Set<String> {
        do {
            return try await userRepository.fetchFollowingIds(uid: userId)
        } catch {
            return []
        }
    }

    private func hydrateAuthorProfiles(for posts: [PostModel]) async {
        let unknownIds = Set(posts.map(\.userId))
            .subtracting(authorProfiles.keys)
            .filter { !$0.isEmpty }
        guard !unknownIds.isEmpty else { return }

        await withTaskGroup(of: UserModel?.self) { group in
            for uid in unknownIds {
                group.addTask { [userRepository] in
                    try? await userRepository.fetchUser(uid: uid)
                }
            }
            for await user in group {
                if let user {
                    authorProfiles[user.uid] = user
                }
            }
        }
    }

    private func makeBackfillTask(for posts: [PostModel]) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            let candidates = posts.filter {
                ($0.gradeSequence.isEmpty || $0.outcomeSequence.isEmpty) && !$0.sessionId.isEmpty
            }
            guard !candidates.isEmpty else { return }

            var updates: [String: (grades: [String], outcomes: [String])] = [:]
            for post in candidates {
                if Task.isCancelled { return }
                do {
                    guard let result = try await self.postRepository.backfillGradeSequence(
                        postId: post.postId, sessionId: post.sessionId
                    ) else { continue }
                    if Task.isCancelled { return }
                    updates[post.postId] = (result.grades, result.outcomes)
                } catch {
                    #if DEBUG
                    print("⚠️ Backfill failed for post \(post.postId): \(error)")
                    #endif
                }
            }

            if Task.isCancelled || updates.isEmpty { return }
            // Apply once to each rail.
            let newFollowing = self.followingPosts
            for idx in newFollowing.indices {
                if let upd = updates[newFollowing[idx].postId] {
                    newFollowing[idx].gradeSequence = upd.grades
                    newFollowing[idx].outcomeSequence = upd.outcomes
                }
            }
            self.followingPosts = newFollowing

            let newDiscover = self.discoverPosts
            for idx in newDiscover.indices {
                if let upd = updates[newDiscover[idx].postId] {
                    newDiscover[idx].gradeSequence = upd.grades
                    newDiscover[idx].outcomeSequence = upd.outcomes
                }
            }
            self.discoverPosts = newDiscover
        }
    }
}
