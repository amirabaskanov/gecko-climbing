import SwiftUI

/// Strava-inspired shareable session summary card
/// Renders as an image for Instagram Stories sharing
struct SessionShareCard: View {
    let gymName: String
    let date: Date
    let topGrade: String
    let topGradeNumeric: Int
    let totalClimbs: Int
    let completedClimbs: Int
    let flashCount: Int
    let durationMinutes: Int

    private var gradeColor: Color {
        Color.gradeColor(for: topGradeNumeric)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Top section: branding
            HStack {
                GeckoLogoView(size: 24, color: .white, showWordmark: true)
                Spacer()
                Text(date.sessionDateFormatted)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)

            // Gym name
            Text(gymName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 8)

            // Hero stat: Top Grade
            VStack(spacing: 4) {
                Text("TOP SEND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1.5)
                Text(topGrade.isEmpty ? "—" : topGrade)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: gradeColor.opacity(0.5), radius: 20)
            }
            .padding(.bottom, 28)

            // Stats row
            HStack(spacing: 0) {
                shareStatItem(
                    value: "\(totalClimbs)",
                    label: "CLIMBS"
                )
                shareDivider
                if flashCount > 0 {
                    shareStatItem(
                        value: "\(flashCount)",
                        label: "FLASHES"
                    )
                    shareDivider
                }
                shareStatItem(
                    value: "\(completedClimbs)",
                    label: "SENDS"
                )
                shareDivider
                shareStatItem(
                    value: formatDuration(durationMinutes),
                    label: "TIME"
                )
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()

            // Bottom branding
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption2)
                Text("Tracked with Gecko")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.4))
            .padding(.bottom, 32)
        }
        .frame(width: 390, height: 520)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color.geckoPrimaryDark, Color.geckoDeepForest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle radial glow from grade color
                RadialGradient(
                    colors: [gradeColor.opacity(0.25), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 220
                )
                .offset(y: -30)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func shareStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var shareDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Share Helper

@MainActor
struct SessionShareHelper {
    @MainActor
    static func renderImage(from card: SessionShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    @MainActor
    static func share(card: SessionShareCard) {
        guard let image = renderImage(from: card) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // Present from the root window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
}
