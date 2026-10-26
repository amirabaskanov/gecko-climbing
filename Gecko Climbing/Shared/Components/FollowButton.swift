import SwiftUI

/// The one follow control. Every social surface (crew rows, suggestion
/// cards, search results, climber profiles) uses this so the interaction
/// and its two states look and feel identical everywhere.
struct FollowButton: View {
    enum Style {
        /// Capsule that sits at the trailing edge of a row or inside a card.
        case compact
        /// Full-width primary action on a climber's profile.
        case prominent
    }

    let isFollowing: Bool
    var style: Style = .compact
    var displayName: String = ""
    let action: () -> Void

    private var isCompact: Bool { style == .compact }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isFollowing {
                    Image(systemName: "checkmark")
                        .font(.system(size: isCompact ? 10 : 12, weight: .heavy))
                }
                Text(isFollowing ? "Following" : "Follow")
            }
            .font(.system(size: isCompact ? 13 : 15, weight: .bold, design: .rounded))
            .foregroundStyle(isFollowing ? Color.primary : Color.geckoOnPrimary)
            .padding(.horizontal, isCompact ? 14 : 20)
            .frame(height: isCompact ? 32 : 46)
            .frame(maxWidth: isCompact ? nil : .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(isFollowing ? Color.geckoInputBackground : Color.geckoPrimary)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.geckoDivider, lineWidth: isFollowing ? 1 : 0)
            )
            .contentShape(Capsule())
        }
        // .borderless keeps the button's hit-testing its own when it sits
        // inside a tappable row; .plain lets the row swallow the tap.
        .buttonStyle(.borderless)
        .animation(.geckoSnappy, value: isFollowing)
        .sensoryFeedback(.selection, trigger: isFollowing)
        .accessibilityLabel(isFollowing ? "Unfollow \(displayName)" : "Follow \(displayName)")
    }
}

#if DEBUG
#Preview("Follow button") {
    VStack(spacing: 16) {
        HStack {
            FollowButton(isFollowing: false, displayName: "Sam") {}
            FollowButton(isFollowing: true, displayName: "Sam") {}
        }
        FollowButton(isFollowing: false, style: .prominent, displayName: "Sam") {}
        FollowButton(isFollowing: true, style: .prominent, displayName: "Sam") {}
    }
    .padding()
    .background(Color.geckoBackground)
}
#endif
