import SwiftUI

/// A climber worth following, as a card. Big avatar carrying the climber's
/// top-grade color with a hold-shaped grade tag at its corner, the name,
/// one line of context (why they're suggested), and a follow button.
/// Shared by the Crew tab and the Discover rail so suggestions look the
/// same wherever they appear.
struct ClimberSuggestionCard: View {
    let user: UserModel
    var reason: SuggestionReason? = nil
    let isFollowing: Bool
    let onToggleFollow: () -> Void
    let onTap: () -> Void

    static let width: CGFloat = 156

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                AvatarView(
                    url: user.profileImageURL,
                    size: 68,
                    name: user.displayName,
                    gradeNumeric: user.highestGradeNumeric
                )
                .overlay(alignment: .bottomTrailing) {
                    if user.highestGradeNumeric >= 0 && !user.highestGrade.isEmpty {
                        GradeTag(gradeNumeric: user.highestGradeNumeric, size: 22)
                            .overlay(GeckoHoldShape().stroke(Color.geckoCard, lineWidth: 2))
                            .offset(x: 8, y: 4)
                    }
                }
                .padding(.top, 4)

                VStack(spacing: 3) {
                    Text(user.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(contextLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(contextIsSocial ? Color.geckoPrimary : Color.geckoSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)

                FollowButton(isFollowing: isFollowing, displayName: user.displayName, action: onToggleFollow)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(width: Self.width)
            .background(Color.geckoCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.geckoDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(user.displayName), \(contextLine)")
    }

    /// Graph signals (mutual follow, follows you) are the strongest reason
    /// to follow someone and get the brand color; everything else is a fact
    /// about the climber in secondary text. "Popular" is a fallback, not a
    /// reason, so it's replaced by what the climber has actually done.
    private var contextLine: String {
        switch reason {
        case .mutualFollow, .followsYou, .sameGym, .gradePeer:
            return reason?.label ?? ""
        case .popular, .none:
            if user.totalSessions > 0 {
                return "\(user.totalSessions) session\(user.totalSessions == 1 ? "" : "s") logged"
            }
            return "New to Gecko"
        }
    }

    private var contextIsSocial: Bool {
        switch reason {
        case .mutualFollow, .followsYou: return true
        default: return false
        }
    }
}

#if DEBUG
#Preview("Suggestion cards") {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ClimberSuggestionCard(
                user: UserModel(uid: "1", displayName: "Sam Rocks", username: "samrocks", followersCount: 12, totalSessions: 24, highestGrade: "V5", highestGradeNumeric: 5),
                reason: .mutualFollow(name: "Phuc"), isFollowing: false, onToggleFollow: {}, onTap: {}
            )
            ClimberSuggestionCard(
                user: UserModel(uid: "2", displayName: "Casey Wall", username: "caseyw", followersCount: 30, totalSessions: 80, highestGrade: "V9", highestGradeNumeric: 9),
                reason: .gradePeer(numeric: 9), isFollowing: true, onToggleFollow: {}, onTap: {}
            )
            ClimberSuggestionCard(
                user: UserModel(uid: "3", displayName: "Morgan Crimp", username: "morganc", followersCount: 5, totalSessions: 0, highestGrade: "", highestGradeNumeric: -1),
                reason: .popular, isFollowing: false, onToggleFollow: {}, onTap: {}
            )
        }
        .padding(16)
    }
    .background(Color.geckoBackground)
}
#endif
