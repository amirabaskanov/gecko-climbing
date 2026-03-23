import SwiftUI
import PhotosUI

struct FeedbackView: View {
    @Bindable var viewModel: FeedbackViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMessageFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.didSubmit {
                    successView
                } else {
                    formView
                }
            }
            .background(Color.geckoBackground)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.didSubmit ? "Done" : "Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }

                if !viewModel.didSubmit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await viewModel.submit() }
                        } label: {
                            Text("Send")
                                .fontWeight(.semibold)
                                .foregroundStyle(viewModel.canSubmit ? Color.geckoPrimary : .secondary)
                        }
                        .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .loadingOverlay(isLoading: viewModel.isLoading, message: "Sending...")
            .errorAlert(error: Binding(
                get: { viewModel.error },
                set: { _ in viewModel.clearError() }
            ))
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Category
                VStack(alignment: .leading, spacing: 10) {
                    Text("What's this about?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    categoryPicker
                }

                // Message
                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    TextField(viewModel.category.placeholder, text: $viewModel.message, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($isMessageFocused)
                        .font(.body)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isMessageFocused ? Color.geckoPrimary : Color.secondary.opacity(0.15),
                                    lineWidth: isMessageFocused ? 2 : 1
                                )
                        )
                        .animation(.geckoSnappy, value: isMessageFocused)
                }

                // Screenshot
                VStack(alignment: .leading, spacing: 10) {
                    Text("Screenshot")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    screenshotPicker

                    Text("Optional — helps us understand the issue faster.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isMessageFocused = true
            }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        HStack(spacing: 10) {
            ForEach(FeedbackCategory.allCases) { cat in
                let isSelected = viewModel.category == cat

                Button {
                    withAnimation(.geckoSnappy) {
                        viewModel.category = cat
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 20, weight: .medium))

                        Text(cat.label)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isSelected
                            ? Color.geckoPrimary.opacity(0.1)
                            : Color.white
                    )
                    .foregroundStyle(
                        isSelected ? Color.geckoPrimary : .secondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected
                                    ? Color.geckoPrimary.opacity(0.3)
                                    : Color.secondary.opacity(0.12),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
                }
                .bouncePress()
            }
        }
    }

    // MARK: - Screenshot Picker

    private var screenshotPicker: some View {
        Group {
            if let preview = viewModel.screenshotPreview {
                HStack(spacing: 14) {
                    preview
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Screenshot attached")
                            .font(.subheadline.weight(.medium))
                        Text("Tap to remove")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.geckoSnappy) {
                            viewModel.removeScreenshot()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .bouncePress()
                }
                .padding(14)
                .cardStyle()
            } else {
                PhotosPicker(
                    selection: $viewModel.selectedPhoto,
                    matching: .screenshots
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.geckoPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.geckoPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("Attach Screenshot")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.geckoPrimary)
                    }
                    .padding(14)
                    .cardStyle()
                }
                .onChange(of: viewModel.selectedPhoto) {
                    Task { await viewModel.loadScreenshot() }
                }
            }
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.geckoSentGreen.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.geckoSentGreen)
            }

            VStack(spacing: 8) {
                Text("Thanks for your feedback!")
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)

                Text("We read every message and it helps\nus make Gecko better.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
