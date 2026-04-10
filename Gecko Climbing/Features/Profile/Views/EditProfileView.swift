import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, bio }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Photo
                    VStack(spacing: 10) {
                        AvatarView(
                            url: viewModel.user?.profileImageURL ?? "",
                            size: 88,
                            name: viewModel.editDisplayName
                        )
                        .overlay {
                            if isUploadingPhoto {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 88, height: 88)
                                ProgressView()
                            }
                        }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change Photo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.geckoPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // MARK: - Fields
                    VStack(spacing: 20) {
                        // Display Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            HStack(spacing: 10) {
                                Image(systemName: "person")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.geckoPrimary)
                                TextField("Your name", text: $viewModel.editDisplayName)
                                    .font(.body)
                                    .focused($focusedField, equals: .name)
                            }
                            .padding(14)
                            .background(Color.geckoInputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        focusedField == .name
                                            ? Color.geckoPrimary
                                            : Color.secondary.opacity(0.15),
                                        lineWidth: focusedField == .name ? 2 : 1
                                    )
                            )
                            .animation(.geckoSnappy, value: focusedField)
                        }

                        // Bio
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.geckoPrimary)
                                    .padding(.top, 2)
                                TextField("Tell climbers about yourself...", text: $viewModel.editBio, axis: .vertical)
                                    .font(.body)
                                    .lineLimit(3, reservesSpace: true)
                                    .focused($focusedField, equals: .bio)
                            }
                            .padding(14)
                            .background(Color.geckoInputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        focusedField == .bio
                                            ? Color.geckoPrimary
                                            : Color.secondary.opacity(0.15),
                                        lineWidth: focusedField == .bio ? 2 : 1
                                    )
                            )
                            .animation(.geckoSnappy, value: focusedField)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.geckoBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.saveProfile()
                            dismiss()
                        }
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.geckoPrimary)
                    }
                    .disabled(isUploadingPhoto)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    isUploadingPhoto = true
                    await viewModel.uploadProfilePhoto(item: newItem)
                    isUploadingPhoto = false
                    selectedPhoto = nil
                }
            }
        }
    }
}
