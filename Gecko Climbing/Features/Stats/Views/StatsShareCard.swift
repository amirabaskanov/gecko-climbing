import SwiftUI

/// Portrait 9:16 stats card — distinct from `WeekInReviewShareCard` (also 9:16
/// but dark forest, single-hero Wrapped vibe).
///
/// This card uses a *light cream* base with deep forest typography and gold
/// accents — feels like a printed athlete profile / trading card. Same brand
/// palette as the app's main stats page so the design feels native.
///
/// Rendered statically — no animations. All colors hard-coded so the card
/// renders identically regardless of the user's system appearance.
struct StatsShareCard: View {
    static let canvasSize = CGSize(width: 360, height: 640)

    let displayName: String
    let highestGrade: String
    let highestGradeNumeric: Int
    let totalSessions: Int
    let totalClimbs: Int
    let totalSends: Int
    let totalDurationMinutes: Int
    let pyramid: [GradeCount]
    let topGyms: [GymCount]

    // Hard-coded palette so the rendered image is appearance-independent
    private let cream = Color(hex: "#FAF8F5")
    private let creamDark = Color(hex: "#EFE9DD")
    private let forest = Color(hex: "#132E25")
    private let forestSoft = Color(hex: "#3D5A4B")
    private let muted = Color(hex: "#7B8B82")

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 14) {
                header
                accentDivider
                identityRow
                lifetimeGrid
                pyramidSection
                gymsSection
                Spacer(minLength: 0)
                accentDivider
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [cream, creamDark],
                startPoint: .top,
                endPoint: .bottom
            )

            // Grade-tinted soft halo top-right for color depth
            RadialGradient(
                colors: [
                    Color.gradeColor(for: highestGradeNumeric).opacity(0.20),
                    Color.clear
                ],
                center: UnitPoint(x: 0.85, y: 0.18),
                startRadius: 0,
                endRadius: 220
            )

            // Subtle forest diagonal at bottom — adds visual interest without noise
            Path { p in
                p.move(to: CGPoint(x: 0, y: Self.canvasSize.height * 0.78))
                p.addLine(to: CGPoint(x: Self.canvasSize.width, y: Self.canvasSize.height * 0.62))
                p.addLine(to: CGPoint(x: Self.canvasSize.width, y: Self.canvasSize.height))
                p.addLine(to: CGPoint(x: 0, y: Self.canvasSize.height))
                p.closeSubpath()
            }
            .fill(Color.geckoPrimary.opacity(0.05))
        }
    }

    private var accentDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.geckoFlashGold.opacity(0),
                        Color.geckoFlashGold.opacity(0.8),
                        Color.geckoFlashGold.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            GeckoLogoView(size: 22, color: .geckoPrimary, showWordmark: true, wordmarkColor: .geckoPrimary)
            Spacer()
            Text(snapshotDate)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Color.geckoPrimary.opacity(0.75))
        }
    }

    private var snapshotDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }

    // MARK: - Identity row (horizontal ID-card)

    private var identityRow: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.gradeGradient(for: highestGradeNumeric))
                    .frame(width: 96, height: 96)
                    .shadow(
                        color: Color.gradeColor(for: highestGradeNumeric).opacity(0.45),
                        radius: 14, x: 0, y: 6
                    )
                Text(GradeDisplaySettings.shared.label(forStored: highestGrade))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(VGrade.textColor(for: highestGradeNumeric))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: 82)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(forest)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 9))
                    Text("Personal best")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                }
                .foregroundStyle(Color.geckoFlashGold)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.geckoFlashGold.opacity(0.18)))
                .overlay(Capsule().stroke(Color.geckoFlashGold.opacity(0.4), lineWidth: 1))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var headline: String {
        if highestGradeNumeric < 0 {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
            return first.isEmpty ? "New climber" : "\(first), climber"
        }
        return "\(GradeDisplaySettings.shared.label(for: highestGradeNumeric)) climber"
    }

    // MARK: - Stats grid (4-up)

    private var lifetimeGrid: some View {
        HStack(spacing: 8) {
            gridTile(value: "\(totalSessions)", label: "Sessions")
            gridTile(value: "\(totalClimbs)", label: "Climbs")
            gridTile(value: "\(totalSends)", label: "Sends")
            gridTile(value: durationLabel, label: "Time")
        }
    }

    private func gridTile(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(forest)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.geckoPrimary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var durationLabel: String {
        if totalDurationMinutes < 60 { return "\(totalDurationMinutes)m" }
        let hours = totalDurationMinutes / 60
        let mins = totalDurationMinutes % 60
        return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
    }

    // MARK: - Pyramid

    private var pyramidSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("SENDS BY GRADE")
            VStack(spacing: 4) {
                let maxCount = pyramid.map(\.count).max() ?? 1
                ForEach(pyramid) { item in
                    pyramidRow(item: item, maxCount: maxCount)
                }
            }
        }
    }

    private func pyramidRow(item: GradeCount, maxCount: Int) -> some View {
        HStack(spacing: 8) {
            Text(GradeDisplaySettings.shared.label(for: item.numeric))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.gradeColor(for: item.numeric))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 24, alignment: .trailing)

            GeometryReader { geo in
                let progress = CGFloat(item.count) / CGFloat(maxCount)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gradeGradient(for: item.numeric))
                        .frame(width: max(geo.size.width * progress, 8))
                }
            }
            .frame(height: 12)

            Text("\(item.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(forestSoft)
                .frame(width: 22, alignment: .leading)
                .monospacedDigit()
        }
    }

    // MARK: - Top gyms

    @ViewBuilder
    private var gymsSection: some View {
        if !topGyms.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("TOP GYMS")
                VStack(spacing: 5) {
                    ForEach(Array(topGyms.enumerated()), id: \.element.id) { index, gym in
                        gymRow(gym: gym, rank: index + 1)
                    }
                }
            }
        }
    }

    private func gymRow(gym: GymCount, rank: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(rankColor(rank)))

            Text(gym.name)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(forest)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(gym.sessionCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(forestSoft)
                .monospacedDigit()
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .geckoFlashGold
        case 2: return Color(hex: "#A8A8A8")
        default: return Color(hex: "#CD7F32")
        }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(Color.geckoPrimary.opacity(0.75))
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Tracked with Gecko · trygecko.app")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(Color.geckoPrimary.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#if DEBUG
#Preview("Stats share card") {
    StatsShareCard(
        displayName: "Alex Stone",
        highestGrade: "V5",
        highestGradeNumeric: 5,
        totalSessions: 24,
        totalClimbs: 247,
        totalSends: 198,
        totalDurationMinutes: 1080,
        pyramid: [
            GradeCount(grade: "V0", numeric: 0, count: 12),
            GradeCount(grade: "V1", numeric: 1, count: 18),
            GradeCount(grade: "V2", numeric: 2, count: 24),
            GradeCount(grade: "V3", numeric: 3, count: 32),
            GradeCount(grade: "V4", numeric: 4, count: 22),
            GradeCount(grade: "V5", numeric: 5, count: 8)
        ],
        topGyms: [
            GymCount(name: "Central Rock Gym", sessionCount: 12),
            GymCount(name: "Brooklyn Boulders", sessionCount: 6),
            GymCount(name: "Movement", sessionCount: 3)
        ]
    )
    .padding()
    .background(.gray.opacity(0.2))
}
#endif
