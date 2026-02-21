import SwiftUI

struct UserSearchView: View {
    @Bindable var viewModel: SocialViewModel

    var body: some View {
        Group {
            if viewModel.isSearching {
                ProgressView().padding()
            } else if !viewModel.searchQuery.isEmpty && viewModel.searchResults.isEmpty {
                Text("No users found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
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
                Text("@\(user.username)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if !user.highestGrade.isEmpty {
                GradeBadge(grade: user.highestGrade, isCompleted: true, size: .small)
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4)
    }
}
