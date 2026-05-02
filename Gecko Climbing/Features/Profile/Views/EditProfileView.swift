import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, username, bio }

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
                        profileField(
                            title: "Display Name",
                            icon: "person",
                            placeholder: "Your name",
                            text: $viewModel.editDisplayName,
                            field: .name
                        )

                        usernameField

                        profileField(
                            title: "Bio",
                            icon: "text.quote",
                            placeholder: "Tell climbers about yourself...",
                            text: $viewModel.editBio,
                            field: .bio,
                            axis: .vertical,
                            lineLimit: 3
                        )
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
                            isSaving = true
                            let didSave = await viewModel.saveProfile()
                            isSaving = false
                            if didSave {
                                dismiss()
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.geckoPrimary)
                        }
                    }
                    .disabled(isUploadingPhoto || isSaving || !viewModel.canSaveProfile)
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
            .onChange(of: viewModel.editUsername) {
                let normalized = viewModel.normalizedEditUsername
                if viewModel.editUsername != normalized {
                    viewModel.editUsername = normalized
                }
            }
        }
    }

    private var usernameField: some View {
        // Suppress the validation warning while the field is empty *and*
        // unfocused, so the form doesn't shout at the user before they've
        // typed anything. Otherwise, surface the message inline as soon as
        // the user starts editing or leaves an invalid value behind.
        let validationMessage = viewModel.usernameValidationMessage
        let showValidationMessage = validationMessage != nil &&
            !(viewModel.editUsername.isEmpty && focusedField != .username)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Username")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                Text("@")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.geckoPrimary)
                    .frame(width: 16)
                TextField("username", text: $viewModel.editUsername)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
            }
            .padding(14)
            .background(Color.geckoInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(usernameFieldBorder(showError: showValidationMessage))
            .animation(.geckoSnappy, value: focusedField)
            .animation(.geckoSnappy, value: showValidationMessage)

            HStack(spacing: 6) {
                Image(systemName: showValidationMessage ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(.caption)
                Text(showValidationMessage
                     ? (validationMessage ?? "")
                     : "Letters, numbers, and underscores. 3-20 characters.")
                    .font(.caption)
            }
            .foregroundStyle(showValidationMessage ? Color.geckoOrange : Color.secondary)
            .padding(.leading, 4)
            .animation(.geckoSnappy, value: showValidationMessage)
        }
    }

    private func usernameFieldBorder(showError: Bool) -> some View {
        let strokeColor: Color = {
            if showError { return Color.geckoOrange }
            if focusedField == .username { return Color.geckoPrimary }
            return Color.secondary.opacity(0.15)
        }()
        let strokeWidth: CGFloat = (showError || focusedField == .username) ? 2 : 1
        return RoundedRectangle(cornerRadius: 14)
            .stroke(strokeColor, lineWidth: strokeWidth)
    }

    private func profileField(
        title: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        axis: Axis = .horizontal,
        lineLimit: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(alignment: axis == .vertical ? .top : .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.geckoPrimary)
                    .padding(.top, axis == .vertical ? 2 : 0)
                TextField(placeholder, text: text, axis: axis)
                    .font(.body)
                    .lineLimit(lineLimit, reservesSpace: axis == .vertical)
                    .focused($focusedField, equals: field)
            }
            .padding(14)
            .background(Color.geckoInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(fieldBorder(for: field))
            .animation(.geckoSnappy, value: focusedField)
        }
    }

    private func fieldBorder(for field: Field) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(
                focusedField == field
                    ? Color.geckoPrimary
                    : Color.secondary.opacity(0.15),
                lineWidth: focusedField == field ? 2 : 1
            )
    }
}
