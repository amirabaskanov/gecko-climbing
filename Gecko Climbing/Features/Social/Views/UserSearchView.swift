import SwiftUI

struct UserSearchView: View {
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        Group {
            if viewModel.isSearching {
                ProgressView().padding()
            } else if !viewModel.searchQuery.isEmpty && viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No climbers found")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Try a different name or username")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(viewModel.searchResults) { user in
                    NavigationLink(value: SocialRoute.friendProfile(uid: user.uid)) {
                        userRow(user)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
    }

    private func userRow(_ user: UserModel) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.profileImageURL, size: 48, name: user.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName).font(.subheadline.weight(.semibold))
                Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()

            let following = viewModel.isFollowing(user.uid)
            Button {
                Task {
                    if following {
                        await viewModel.unfollow(user: user)
                    } else {
                        await viewModel.follow(user: user)
                    }
                }
            } label: {
                Text(following ? "Following" : "Follow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        following ? AnyShapeStyle(Color.geckoInputBackground) : AnyShapeStyle(Color.geckoPrimary)
                    )
                    .foregroundStyle(following ? Color.primary : Color.white)
                    .overlay(
                        Capsule().stroke(Color.geckoDivider, lineWidth: following ? 1 : 0)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.geckoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 4)
    }
}
