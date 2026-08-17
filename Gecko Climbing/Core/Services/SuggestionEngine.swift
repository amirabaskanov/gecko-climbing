import Foundation

// MARK: - Suggestion Reason

/// Why a user is being suggested. One reason per suggestion — the
/// highest-precedence signal that fired (mutual > follows-you > gym > grade).
enum SuggestionReason: Equatable {
    case mutualFollow(name: String)
    case followsYou
    case sameGym(gym: String)
    case gradePeer(numeric: Int)
    case popular

    /// Human-readable reason line for suggestion cards.
    var label: String {
        switch self {
        case .mutualFollow(let name):
            return "Followed by \(name)"
        case .followsYou:
            return "Follows you"
        case .sameGym(let gym):
            // Gym names arrive lowercased (canonical comparison form);
            // re-capitalize for display.
            return "Climbs at \(gym.capitalized)"
        case .gradePeer(let numeric):
            // Route through the viewer's grade-system preference so Font/
            // Circuit users see "6C climber", not "V5 climber".
            return "\(GradeDisplaySettings.shared.label(for: numeric)) climber like you"
        case .popular:
            return "Popular in the community"
        }
    }
}

// MARK: - Signals

/// Everything `SuggestionEngine.rank` needs about the viewer's social graph,
/// pre-fetched so ranking itself is pure and synchronously testable.
struct SuggestionSignals {
    /// Users the viewer already follows — excluded from suggestions entirely.
    let viewerFollowingIds: Set<String>
    /// Users who follow the viewer (drives "Follows you").
    let viewerFollowerIds: Set<String>
    /// candidateUid → display names of the viewer's follows who follow them.
    let friendsOfFriends: [String: [String]]
    /// candidateUid → gyms they climb at (lowercased, trimmed).
    let candidateGyms: [String: Set<String>]
    /// The viewer's home gyms (lowercased, trimmed).
    let viewerGyms: Set<String>
    /// The viewer's highest sent grade; negative means none yet.
    let viewerGradeNumeric: Int
    let blockedIds: Set<String>
    let demoIds: Set<String>
    let viewerUid: String
}

// MARK: - Scored Suggestion

struct ScoredSuggestion: Identifiable {
    let user: UserModel
    let score: Double
    let reason: SuggestionReason

    var id: String { user.uid }
}

// MARK: - Engine (pure)

/// Client-side people ranking. Pure function of candidates + signals; all
/// weights live in `FeedConfig` so tuning never touches this logic.
enum SuggestionEngine {
    static func rank(candidates: [UserModel], signals: SuggestionSignals) -> [ScoredSuggestion] {
        candidates.compactMap { candidate -> ScoredSuggestion? in
            let uid = candidate.uid
            guard uid != signals.viewerUid,
                  !signals.demoIds.contains(uid),
                  !signals.blockedIds.contains(uid),
                  !signals.viewerFollowingIds.contains(uid) else { return nil }

            let mutualNames = signals.friendsOfFriends[uid] ?? []
            let followsYou = signals.viewerFollowerIds.contains(uid)
            // Deterministic pick when several gyms overlap.
            let sharedGym = signals.candidateGyms[uid]?
                .intersection(signals.viewerGyms)
                .sorted()
                .first
            let isGradePeer = signals.viewerGradeNumeric >= 0
                && candidate.highestGradeNumeric >= 0
                && abs(candidate.highestGradeNumeric - signals.viewerGradeNumeric) <= FeedConfig.gradeProximityWindow

            var score = Double(min(mutualNames.count, FeedConfig.suggestionMutualCap))
                * FeedConfig.suggestionMutualWeight
            if followsYou { score += FeedConfig.suggestionFollowsYouWeight }
            if sharedGym != nil { score += FeedConfig.suggestionGymWeight }
            if isGradePeer { score += FeedConfig.suggestionGradePeerWeight }
            // Social-proof tiebreak — log-scaled so follower counts never
            // outweigh a real graph signal.
            score += log10(Double(max(candidate.followersCount, 0)) + 1)

            let reason: SuggestionReason
            if let name = mutualNames.first {
                reason = .mutualFollow(name: name)
            } else if followsYou {
                reason = .followsYou
            } else if let sharedGym {
                reason = .sameGym(gym: sharedGym)
            } else if isGradePeer {
                reason = .gradePeer(numeric: candidate.highestGradeNumeric)
            } else {
                reason = .popular
            }

            return ScoredSuggestion(user: candidate, score: score, reason: reason)
        }
        .sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.user.uid < $1.user.uid
        }
    }
}

// MARK: - Loader (orchestration)

/// Fetches the candidate pool + graph signals and runs the engine. Every
/// fetch is error-tolerant: a failed signal degrades to empty (weaker
/// ranking, still suggestions) rather than throwing.
final class SuggestionLoader {
    /// - Parameters:
    ///   - viewerUser: Current user's profile (grade + block list); nil when
    ///     the fetch failed — those signals just don't fire.
    ///   - discoverPosts: Already-fetched Discover posts, mined for candidate
    ///     gym overlap at zero extra reads. Pass `[]` when unavailable.
    ///   - viewerGyms: The viewer's home gyms, lowercased + trimmed.
    func load(
        viewerUid: String,
        viewerUser: UserModel?,
        followingIds: Set<String>,
        discoverPosts: [PostModel],
        viewerGyms: Set<String>,
        userRepository: any UserRepositoryProtocol,
        limit: Int
    ) async -> [ScoredSuggestion] {
        let exclude = followingIds.union([viewerUid])
        let candidates = (try? await userRepository.suggestedClimbers(
            excluding: exclude,
            limit: FeedConfig.suggestionCandidatePoolLimit
        )) ?? []
        guard !candidates.isEmpty else { return [] }

        let candidateIds = Set(candidates.map(\.uid))

        async let friendsOfFriendsTask = fetchFriendsOfFriends(
            viewerUid: viewerUid,
            candidateIds: candidateIds,
            userRepository: userRepository
        )
        async let followerIdsTask = fetchFollowerIds(
            viewerUid: viewerUid,
            userRepository: userRepository
        )

        var candidateGyms: [String: Set<String>] = [:]
        for post in discoverPosts {
            let gym = post.gymName.trimmedGymName.lowercased()
            guard !gym.isEmpty, candidateIds.contains(post.userId) else { continue }
            candidateGyms[post.userId, default: []].insert(gym)
        }
        for candidate in candidates {
            if let gym = candidate.homeGymOverride?.trimmedGymName.lowercased(), !gym.isEmpty {
                candidateGyms[candidate.uid, default: []].insert(gym)
            }
        }

        let signals = SuggestionSignals(
            viewerFollowingIds: followingIds,
            viewerFollowerIds: await followerIdsTask,
            friendsOfFriends: await friendsOfFriendsTask,
            candidateGyms: candidateGyms,
            viewerGyms: viewerGyms,
            viewerGradeNumeric: viewerUser?.highestGradeNumeric ?? -1,
            blockedIds: Set(viewerUser?.blockedUserIds ?? []),
            demoIds: FeedConfig.demoUserIds,
            viewerUid: viewerUid
        )

        return Array(SuggestionEngine.rank(candidates: candidates, signals: signals).prefix(limit))
    }

    /// candidateUid → display names of the viewer's follows who follow them.
    /// Fan-out is capped at `suggestionFriendFanOutLimit` reads; the display
    /// list from `fetchFollowing` (50 per friend) is plenty for a signal.
    private func fetchFriendsOfFriends(
        viewerUid: String,
        candidateIds: Set<String>,
        userRepository: any UserRepositoryProtocol
    ) async -> [String: [String]] {
        let friends = (try? await userRepository.fetchFollowing(uid: viewerUid)) ?? []
        guard !friends.isEmpty else { return [:] }

        var map: [String: [String]] = [:]
        await withTaskGroup(of: (name: String, followedCandidates: [String]).self) { group in
            for friend in friends.prefix(FeedConfig.suggestionFriendFanOutLimit) {
                let friendUid = friend.uid
                let friendName = friend.displayName
                group.addTask { [userRepository] in
                    let theirFollowing = (try? await userRepository.fetchFollowing(uid: friendUid)) ?? []
                    let followed = theirFollowing.map(\.uid).filter(candidateIds.contains)
                    return (friendName, followed)
                }
            }
            for await (name, followedCandidates) in group {
                guard !name.isEmpty else { continue }
                for uid in followedCandidates {
                    map[uid, default: []].append(name)
                }
            }
        }
        return map
    }

    private func fetchFollowerIds(
        viewerUid: String,
        userRepository: any UserRepositoryProtocol
    ) async -> Set<String> {
        let followers = (try? await userRepository.fetchFollowers(uid: viewerUid)) ?? []
        return Set(followers.map(\.uid))
    }
}
