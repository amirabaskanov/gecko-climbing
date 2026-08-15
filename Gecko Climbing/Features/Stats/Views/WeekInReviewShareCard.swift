import SwiftUI

/// Story-style portrait card designed to be rendered to a UIImage via
/// `ImageRenderer` and shared. Sized at 9:16 (Instagram Story aspect),
/// rendered at scale 3 for a 1080x1920 final image.
///
/// This view is *static* — no entrance animations, no state — so it
/// renders deterministically and quickly.
struct WeekInReviewShareCard: View {
    static let canvasSize = CGSize(width: 360, height: 640)

    let displayName: String
    let dateRangeLabel: String
    let hardestSendLabel: String
    let hardestSendNumeric: Int
    let isPR: Bool
    let totalSessions: Int
    let totalClimbs: Int
    let totalSends: Int
    let totalDurationMinutes: Int
    let sendRatePercent: Int
    let weekDays: [Date]
    let daysClimbed: Set<Date>
    let wheelhouse: GradeCount?
    let topFlash: GradeCount?

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                hero
                Spacer(minLength: 0)
                statsBlock
                daysBlock
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            // Forest gradient base
            LinearGradient(
                colors: [
                    Color(hex: "#0A1713"),
                    Color(hex: "#132E25"),
                    Color.geckoPrimary.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Grade-tinted halo behind the hero
            RadialGradient(
                colors: [
                    Color.gradeColor(for: hardestSendNumeric).opacity(0.35),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .blendMode(.screen)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                GeckoLogoView(size: 22, color: .white, showWordmark: true, wordmarkColor: .white)
            }
            Spacer()
            Text(dateRangeLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Text(headlineText)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.gradeColor(for: hardestSendNumeric),
                                Color.gradeColor(for: hardestSendNumeric).opacity(0.85)
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 200
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(
                        color: Color.gradeColor(for: hardestSendNumeric).opacity(0.6),
                        radius: 28, x: 0, y: 0
                    )

                Text(GradeDisplaySettings.shared.label(forStored: hardestSendLabel))
                    .font(.system(size: 86, weight: .black, design: .rounded))
                    .foregroundStyle(VGrade.textColor(for: hardestSendNumeric))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .frame(maxWidth: 170)
            }

            if isPR {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                    Text("All-time personal best")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(0.3)
                }
                .foregroundStyle(Color.geckoFlashGold)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.black.opacity(0.35))
                )
                .overlay(
                    Capsule().stroke(Color.geckoFlashGold.opacity(0.5), lineWidth: 1)
                )
            } else if hardestSendNumeric >= 0 {
                Text("Hardest send this week")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var headlineText: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "My Week in Climbing"
        }
        // First name only for headline punch
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return "\(first)'s Week in Climbing"
    }

    // MARK: - Stats grid

    private var statsBlock: some View {
        HStack(spacing: 10) {
            statTile(value: "\(totalSessions)", label: "Sessions")
            statTile(value: "\(totalClimbs)", label: "Climbs")
            statTile(value: durationLabel, label: "Time")
            statTile(value: "\(sendRatePercent)%", label: "Send rate")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var durationLabel: String {
        if totalDurationMinutes < 60 { return "\(totalDurationMinutes)m" }
        let hours = totalDurationMinutes / 60
        let mins = totalDurationMinutes % 60
        return mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
    }

    // MARK: - Days climbed + wheelhouse

    private var daysBlock: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Array(weekDays.enumerated()), id: \.element) { _, day in
                    let lit = daysClimbed.contains(day)
                    Circle()
                        .fill(lit ? Color.geckoMint : Color.white.opacity(0.18))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if lit {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(Color.geckoDeepForest)
                            }
                        }
                }
            }
            .padding(.top, 18)

            if let wheelhouse {
                wheelhouseLine(wheelhouse)
            } else if let topFlash {
                flashLine(topFlash)
            }
        }
    }

    private func wheelhouseLine(_ grade: GradeCount) -> some View {
        HStack(spacing: 8) {
            Text("Your wheelhouse")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.gradeColor(for: grade.numeric))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text(GradeDisplaySettings.shared.label(for: grade.numeric))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(VGrade.textColor(for: grade.numeric))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .frame(maxWidth: 16)
                    )
                Text("\(grade.count) sends")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private func flashLine(_ flash: GradeCount) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color.geckoFlashGold)
            Text("\(flash.count) flashes · top \(GradeDisplaySettings.shared.label(for: flash.numeric))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Tracked with Gecko · trygecko.app")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 18)
    }
}

#if DEBUG
#Preview("Share card") {
    WeekInReviewShareCard(
        displayName: "Alex Stone",
        dateRangeLabel: "APR 25 – MAY 1",
        hardestSendLabel: "V5",
        hardestSendNumeric: 5,
        isPR: true,
        totalSessions: 1,
        totalClimbs: 9,
        totalSends: 7,
        totalDurationMinutes: 3,
        sendRatePercent: 77,
        weekDays: (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) },
        daysClimbed: [Calendar.current.startOfDay(for: Date())],
        wheelhouse: GradeCount(grade: "V3", numeric: 3, count: 2),
        topFlash: GradeCount(grade: "V3", numeric: 3, count: 2)
    )
    .padding()
    .background(.black)
}
#endif
