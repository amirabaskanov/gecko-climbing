import SwiftUI

struct NotificationPrePromptView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.dismiss) private var dismiss

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            GeckoLogoView(size: 72, color: .geckoPrimary)

            VStack(spacing: 12) {
                Text("Stay in the loop")
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Get notified when friends react to your sends, hit new PRs, or post a session at your gym.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await requestPermission() }
                } label: {
                    HStack(spacing: 8) {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Turn on notifications")
                            .font(.body.weight(.semibold))
                            .fontDesign(.rounded)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.geckoPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .bouncePress()
                .disabled(isRequesting)

                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.subheadline.weight(.medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.geckoBackground)
    }

    private func requestPermission() async {
        isRequesting = true
        _ = await notificationService.requestAuthorization()
        isRequesting = false
        dismiss()
    }
}
