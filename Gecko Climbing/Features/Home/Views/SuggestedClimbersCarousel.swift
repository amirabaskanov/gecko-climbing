import SwiftUI

/// Horizontal row of climbers to follow. Lives on the Discover rail and in
/// the empty Following state; the Crew tab renders the same cards, so a
/// suggestion looks identical wherever the reader meets it.
struct SuggestedClimbersCarousel: View {
    let users: [UserModel]
    var followingIds: Set<String> = []
    /// Per-uid reason from the suggestion engine.
    var reasons: [String: SuggestionReason] = [:]
    var onFollow: (UserModel) -> Void = { _ in }
    var onUnfollow: (UserModel) -> Void = { _ in }
    var onTap: (UserModel) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SocialSectionHeader(title: "Find your crew")

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(users, id: \.uid) { user in
                        let following = followingIds.contains(user.uid)
                        ClimberSuggestionCard(
                            user: user,
                            reason: reasons[user.uid],
                            isFollowing: following,
                            onToggleFollow: { following ? onUnfollow(user) : onFollow(user) },
                            onTap: { onTap(user) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

#if DEBUG
#Preview("Carousel") {
    SuggestedClimbersCarousel(
        users: [
            UserModel(uid: "1", displayName: "Sam Rocks", username: "samrocks",
                      followersCount: 12, totalSessions: 24, highestGrade: "V5", highestGradeNumeric: 5),
            UserModel(uid: "2", displayName: "Casey Wall", username: "caseyw",
                      followersCount: 30, totalSessions: 80, highestGrade: "V9", highestGradeNumeric: 9),
            UserModel(uid: "3", displayName: "Morgan Crimp", username: "morganc",
                      followersCount: 5, totalSessions: 8, highestGrade: "V2", highestGradeNumeric: 2),
            UserModel(uid: "4", displayName: "Jordan Peak", username: "jordanp",
                      followersCount: 18, totalSessions: 40, highestGrade: "V7", highestGradeNumeric: 7)
        ],
        followingIds: ["2"],
        reasons: ["1": .mutualFollow(name: "Phuc"), "4": .sameGym(gym: "movement denver")]
    )
    .padding(.vertical, 16)
    .background(Color.geckoBackground)
    .preferredColorScheme(.light)
}
#endif
