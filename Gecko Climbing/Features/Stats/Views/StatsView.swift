import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.displayScale) private var displayScale
    @State private var viewModel: StatsViewModel?
    @State private var appeared = false
    @State private var shareImage: Image?

    var body: some View {
        contentBody
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .errorAlert(error: Binding(
                get: { viewModel?.error },
                set: { viewModel?.error = $0 }
            ))
            .onAppear {
                // Reuse the VM across appearances but always re-fetch: a session
                // edited elsewhere (e.g. SessionDetailView) must be reflected when
                // the user returns here. The refresh is silent — `contentBody`
                // keeps showing existing data while `isLoading` is true, so there's
                // no spinner flash once stats have loaded once.
                let vm = viewModel ?? StatsViewModel(
                    sessionRepository: appEnv.sessionRepository,
                    userId: authViewModel.currentUserId
                )
                viewModel = vm
                Task { await vm.loadStats() }
            }
    }

    @ViewBuilder
    private var contentBody: some View {
        if let vm = viewModel {
            if vm.isLoading && !vm.hasAnyData {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.hasAnyData {
                content(vm)
            } else {
                StatsEmptyState()
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(_ vm: StatsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                IdentityHero(
                    grade: vm.highestGrade,
                    gradeNumeric: vm.highestGradeNumeric,
                    appeared: appeared
                )

                LifetimeStrip(
                    sessions: vm.totalSessions,
                    climbs: vm.totalClimbs,
                    minutes: vm.totalDurationMinutes
                )

                if !vm.gradePyramidData.isEmpty {
                    GradePyramidCard(
                        data: vm.gradePyramidData,
                        appeared: appeared
                    )
                }

                if vm.totalClimbs > 0 {
                    OutcomeDonutCard(distribution: vm.outcomeDistribution)
                }

                ActivityHeatmapCard(dailyCounts: vm.dailyClimbCounts)

                if !vm.topGyms.isEmpty {
                    TopGymsCard(gyms: vm.topGyms, totalSessions: vm.totalSessions)
                }

                if vm.progressData.count > 1 {
                    ProgressChartCard(data: vm.progressData, appeared: appeared)
                }

                ShareStatsCTA(shareImage: shareImage)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 56)
        .background(Color.geckoBackground)
        .refreshable { await vm.loadStats() }
        .onAppear {
            withAnimation(.geckoBounce.delay(0.05)) { appeared = true }
        }
        .task(id: vm.totalClimbs) {
            shareImage = renderShareImage(vm: vm)
        }
    }

    @MainActor
    private func renderShareImage(vm: StatsViewModel) -> Image? {
        let card = StatsShareCard(
            displayName: authViewModel.currentUserDisplayName,
            highestGrade: vm.highestGrade,
            highestGradeNumeric: vm.highestGradeNumeric,
            totalSessions: vm.totalSessions,
            totalClimbs: vm.totalClimbs,
            totalSends: vm.totalSends,
            totalDurationMinutes: vm.totalDurationMinutes,
            pyramid: vm.gradePyramidData,
            topGyms: vm.topGyms
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = max(displayScale, 3.0)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Share CTA

private struct ShareStatsCTA: View {
    let shareImage: Image?

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Looking strong.")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.geckoPrimary)
                Text("Your stats, on one card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let shareImage {
                ShareLink(
                    item: shareImage,
                    subject: Text("My climbing stats"),
                    message: Text("My lifetime climbing stats with Gecko"),
                    preview: SharePreview(
                        "My climbing stats",
                        image: shareImage
                    )
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share my stats")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(Color.geckoPrimary))
                }
                .buttonStyle(.plain)
                .bouncePress()
            } else {
                ProgressView()
                    .frame(height: 44)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardStyle()
    }
}

// MARK: - Identity Hero

private struct IdentityHero: View {
    let grade: String
    let gradeNumeric: Int
    let appeared: Bool
    @State private var glow = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.gradeGradient(for: gradeNumeric))
                    .frame(width: 150, height: 150)
                    .shadow(
                        color: Color.gradeColor(for: gradeNumeric).opacity(0.45),
                        radius: glow ? 30 : 18,
                        x: 0, y: 0
                    )
                Text(GradeDisplaySettings.shared.label(forStored: grade))
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .frame(maxWidth: 126)
                    .foregroundStyle(VGrade.textColor(for: gradeNumeric))
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .animation(.geckoBounce, value: appeared)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }

            VStack(spacing: 4) {
                Text(headline)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Lifetime peak")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyleElevated()
    }

    private var headline: String {
        if gradeNumeric < 0 { return "New climber" }
        return "\(GradeDisplaySettings.shared.label(for: gradeNumeric)) climber"
    }
}

// MARK: - Lifetime Strip (count-up tiles)

private struct LifetimeStrip: View {
    let sessions: Int
    let climbs: Int
    let minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            CountUpTile(value: sessions, label: "Sessions", icon: "figure.climbing", tint: .geckoPrimary, delay: 0.05)
            CountUpTile(value: climbs, label: "Climbs", icon: "mountain.2.fill", tint: .geckoOrange, delay: 0.15)
            CountUpTile(value: minutes, label: timeLabel, icon: "clock.fill", tint: .geckoAttemptBlue, delay: 0.25, useDuration: true, totalMinutes: minutes)
        }
    }

    private var timeLabel: String { "Time" }
}

private struct CountUpTile: View {
    let value: Int
    let label: String
    let icon: String
    let tint: Color
    let delay: Double
    var useDuration: Bool = false
    var totalMinutes: Int = 0

    @State private var displayValue: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
            Text(displayText)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: displayValue))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [tint.opacity(0.10), tint.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .cardStyle()
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(delay)) {
                displayValue = Double(value)
            }
        }
    }

    private var displayText: String {
        if useDuration {
            return formatDuration(Int(displayValue))
        }
        return Int(displayValue).formatted()
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h\(remaining)m" : "\(hours)h"
    }
}

// MARK: - Grade Pyramid Card (animated bars)

private struct GradePyramidCard: View {
    let data: [GradeCount]
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Grade pyramid", subtitle: "Sends by grade")

            VStack(spacing: 8) {
                let maxCount = data.map(\.count).max() ?? 1
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    PyramidBar(
                        item: item,
                        maxCount: maxCount,
                        appeared: appeared,
                        index: index
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct PyramidBar: View {
    let item: GradeCount
    let maxCount: Int
    let appeared: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(GradeDisplaySettings.shared.label(for: item.numeric))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.gradeColor(for: item.numeric))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 28, alignment: .trailing)

            GeometryReader { geo in
                let fullWidth = geo.size.width
                let progress = CGFloat(item.count) / CGFloat(maxCount)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.geckoDivider.opacity(0.4))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gradeGradient(for: item.numeric))
                        .frame(width: appeared ? max(fullWidth * progress, 18) : 0)
                        .animation(
                            .geckoSpring.delay(0.1 + Double(index) * 0.04),
                            value: appeared
                        )
                }
            }
            .frame(height: 22)

            Text("\(item.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
                .monospacedDigit()
        }
    }
}

// MARK: - Outcome Donut

private struct OutcomeDonutCard: View {
    let distribution: [OutcomeShare]
    @State private var animated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Outcome split", subtitle: "How your climbs end up")

            HStack(spacing: 18) {
                Chart(distribution) { share in
                    SectorMark(
                        angle: .value("Count", animated ? share.count : 0),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(share.outcome.color)
                    .cornerRadius(4)
                }
                .frame(width: 140, height: 140)
                .animation(.easeOut(duration: 0.9), value: animated)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(distribution) { share in
                        outcomeRow(share)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) {
                animated = true
            }
        }
    }

    private func outcomeRow(_ share: OutcomeShare) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(share.outcome.color)
                .frame(width: 9, height: 9)
            Text(share.outcome.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            Text("\(Int((share.fraction * 100).rounded()))%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Activity Heatmap (last 13 weeks)

private struct ActivityHeatmapCard: View {
    let dailyCounts: [Date: Int]

    /// Number of weeks to display.
    private static let weekCount = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Activity",
                subtitle: "Climbs per day, last \(Self.weekCount) weeks"
            )

            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                heatmapGrid
            }

            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(0..<5) { intensity in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(forIntensity: intensity))
                        .frame(width: 14, height: 14)
                }
                Text("More")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var weekdayLabels: some View {
        VStack(spacing: 4) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 12, height: 14)
            }
        }
    }

    private var heatmapGrid: some View {
        let columns = heatmapDates() // [[Date]] of weekCount columns x 7 rows
        return HStack(spacing: 4) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 4) {
                    ForEach(week, id: \.self) { day in
                        let count = dailyCounts[day] ?? 0
                        let intensity = intensity(for: count)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(forIntensity: intensity))
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                            .opacity(day > Date() ? 0.3 : 1.0) // future days dimmed
                    }
                }
            }
        }
        .frame(height: 14 * 7 + 4 * 6)
    }

    /// Returns `[week][weekday]` matrix of dates ending on the current week's Sunday.
    private func heatmapDates() -> [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1=Sun..7=Sat
        let offsetToMonday = (weekday + 5) % 7
        guard let thisMonday = calendar.date(byAdding: .day, value: -offsetToMonday, to: today) else {
            return []
        }
        let earliestMonday = calendar.date(byAdding: .day, value: -7 * (Self.weekCount - 1), to: thisMonday)!

        return (0..<Self.weekCount).map { weekIdx in
            let weekStart = calendar.date(byAdding: .day, value: weekIdx * 7, to: earliestMonday)!
            return (0..<7).compactMap { dow in
                calendar.date(byAdding: .day, value: dow, to: weekStart)
            }
        }
    }

    private func intensity(for count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1...2: return 1
        case 3...5: return 2
        case 6...10: return 3
        default: return 4
        }
    }

    private func color(forIntensity level: Int) -> Color {
        switch level {
        case 0: return Color.geckoDivider.opacity(0.45)
        case 1: return Color.geckoPrimary.opacity(0.30)
        case 2: return Color.geckoPrimary.opacity(0.55)
        case 3: return Color.geckoPrimary.opacity(0.80)
        default: return Color.geckoPrimary
        }
    }
}

// MARK: - Top Gyms

private struct TopGymsCard: View {
    let gyms: [GymCount]
    let totalSessions: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Top gyms", subtitle: "Where you climb most")

            VStack(spacing: 10) {
                ForEach(Array(gyms.enumerated()), id: \.element.id) { index, gym in
                    gymRow(gym, rank: index + 1)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func gymRow(_ gym: GymCount, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(rankColor(rank)))

            VStack(alignment: .leading, spacing: 2) {
                Text(gym.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                GeometryReader { geo in
                    let fraction = totalSessions > 0
                        ? CGFloat(gym.sessionCount) / CGFloat(totalSessions)
                        : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.geckoDivider.opacity(0.4))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rankColor(rank))
                            .frame(width: max(geo.size.width * fraction, 8))
                    }
                }
                .frame(height: 6)
            }

            Text("\(gym.sessionCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .geckoPrimary
        case 2: return .geckoFlashGold
        default: return .geckoOrange
        }
    }
}

// MARK: - Progress Chart Card

private struct ProgressChartCard: View {
    let data: [SessionProgress]
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Grade progression", subtitle: "Hardest send per session")
            ProgressChartView(data: data)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Empty state

private struct StatsEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.geckoPrimary.opacity(0.4))
            Text("Stats unlock with your first session")
                .font(.title3.weight(.bold))
            Text("Log a climb and your hero grade, pyramid, and progress chart all light up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.geckoBackground)
    }
}
