import SwiftUI

/// Horizontal scrolling row of climbers to potentially follow. Injected into:
/// 1) the empty Following state (primary CTA — fight the empty feed)
/// 2) Discover, near the top (always-visible discovery surface)
///
/// Each card surfaces the *minimum signal a climber needs* to decide whether
/// to follow:
/// - Display name + handle (identity)
/// - Avatar (face)
/// - Highest grade barrel (skill level — climbers care a LOT about this)
/// - Session count (activity — how alive is this account?)
/// - One-tap Follow button with optimistic state flip
///
/// Visual choices:
/// - 144pt-wide cards. Wide enough to fit a full name + grade barrel without
///   clipping; narrow enough that ~2.5 fit on screen, signalling there's more
///   to scroll to.
/// - Avatar sits *over* a tinted top hero band that uses the climber's
///   highest-grade color. This is the "climber's identity color" and lets
///   the carousel read at a glance — green cards are V0-V2 climbers, gold
///   are V3-V4, red are V7+, etc.
/// - Follow button is the same capsule used in `UserSearchView` so the
///   interaction is consistent across the app.
struct SuggestedClimbersCarousel: View {
    let users: [UserModel]
    var followingIds: Set<String> = []
    var onFollow: (UserModel) -> Void = { _ in }
    var onUnfollow: (UserModel) -> Void = { _ in }
    var onTap: (UserModel) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("CLIMBERS YOU MIGHT KNOW")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Color.geckoPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(users, id: \.uid) { user in
                        SuggestedClimberCard(
                            user: user,
                            isFollowing: followingIds.contains(user.uid),
                            onFollow: { onFollow(user) },
                            onUnfollow: { onUnfollow(user) },
                            onTap: { onTap(user) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Single climber card inside the carousel. Owned-state is local to the
/// chip — parent passes `isFollowing` and follow/unfollow handlers, and the
/// card optimistically updates the visual state immediately on tap.
struct SuggestedClimberCard: View {
    let user: UserModel
    let isFollowing: Bool
    let onFollow: () -> Void
    let onUnfollow: () -> Void
    let onTap: () -> Void

    /// Locally-mirrored follow state so the button responds instantly. The
    /// parent's `isFollowing` is the source of truth; we sync to it via
    /// `.onChange` so an outside flip (e.g. unfollow from another screen)
    /// still updates this card.
    @State private var localFollowing: Bool = false

    var body: some View {
        let gradeColor = Color.gradeColor(for: user.highestGradeNumeric)
        let cardWidth: CGFloat = 144

        Button(action: onTap) {
            VStack(spacing: 0) {
                // Hero band — colored by the climber's highest grade so the
                // carousel telegraphs skill level at a glance. Two stacked
                // gradients give the band a soft top-light → bottom-shadow
                // depth so the avatar reads as sitting *on* the card, not
                // just stamped onto a flat color.
                ZStack(alignment: .center) {
                    LinearGradient(
                        colors: [gradeColor.opacity(0.95), gradeColor.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(height: 60)

                    AvatarView(url: user.profileImageURL, size: 66, name: user.displayName)
                        .overlay(
                            Circle()
                                .stroke(Color.geckoCard, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                        .offset(y: 24)
                }
                .frame(maxWidth: .infinity)

                // Body — name, handle, stat line.
                VStack(spacing: 2) {
                    Spacer().frame(height: 30)

                    Text(user.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text("@\(user.username)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.geckoSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 6) {
                        if !user.highestGrade.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 8, weight: .heavy))
                                Text(GradeDisplaySettings.shared.label(for: user.highestGradeNumeric))
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(gradeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(gradeColor.opacity(0.15)))
                        }
                        if user.totalSessions > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 8, weight: .heavy))
                                Text("\(user.totalSessions)")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(Color.geckoSecondaryText)
                        }
                    }
                    .padding(.top, 4)

                    followButton
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }
            .frame(width: cardWidth)
            .background(Color.geckoCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.geckoDivider, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear { localFollowing = isFollowing }
        .onChange(of: isFollowing) { _, new in localFollowing = new }
    }

    private var followButton: some View {
        Button {
            withAnimation(.geckoSnappy) { localFollowing.toggle() }
            if localFollowing {
                onFollow()
            } else {
                onUnfollow()
            }
        } label: {
            Text(localFollowing ? "Following" : "Follow")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(localFollowing ? Color.primary : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(localFollowing ? AnyShapeStyle(Color.geckoInputBackground) : AnyShapeStyle(Color.geckoPrimary))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.geckoDivider, lineWidth: localFollowing ? 1 : 0)
                )
        }
        // .borderless keeps this button's hit region its own — nested inside
        // the whole-card Button, .plain can let the card steal the tap and
        // navigate instead of following.
        .buttonStyle(.borderless)
        .accessibilityLabel(localFollowing ? "Unfollow \(user.displayName)" : "Follow \(user.displayName)")
        .sensoryFeedback(.selection, trigger: localFollowing)
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
        followingIds: ["2"]
    )
    .padding(.vertical, 16)
    .background(Color.geckoBackground)
    .preferredColorScheme(.light)
}
#endif
