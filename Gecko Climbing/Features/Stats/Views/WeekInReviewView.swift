import SwiftUI

struct WeekInReviewView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WeekInReviewViewModel?
    @State private var heroAppeared = false
    @State private var shareImage: Image?

    var body: some View {
        contentBody
            .background(backgroundGradient)
            .navigationTitle("Week in Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .errorAlert(error: Binding(
                get: { viewModel?.error },
                set: { viewModel?.error = $0 }
            ))
            .task {
                if viewModel == nil {
                    let vm = WeekInReviewViewModel(
                        sessionRepository: appEnv.sessionRepository,
                        userRepository: appEnv.userRepository,
                        userId: authViewModel.currentUserId
                    )
                    viewModel = vm
                    await vm.load()
                }
            }
    }

    @ViewBuilder
    private var contentBody: some View {
        if let vm = viewModel {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.hasActivity {
                storyScroll(vm)
            } else if vm.hasLifetimeActivity {
                EmptyReturning(vm: vm, onClose: { dismiss() })
            } else {
                EmptyFirstTimer(onClose: { dismiss() })
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.geckoBackground,
                Color.geckoPrimary.opacity(0.06),
                Color.geckoBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func storyScroll(_ vm: WeekInReviewViewModel) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                TitleCard(rangeLabel: vm.dateRangeLabel, appeared: heroAppeared)
                HardestSendCard(
                    grade: vm.hardestSendLabel,
                    numeric: vm.hardestSendNumeric ?? -1,
                    isPR: vm.isHardestSendPR,
                    appeared: heroAppeared
                )
                VolumeStrip(
                    sessions: vm.totalSessions,
                    climbs: vm.totalClimbs,
                    minutes: vm.totalDurationMinutes
                )
                SendRateRing(
                    sendRate: vm.sendRate,
                    sends: vm.totalSends,
                    total: vm.totalClimbs
                )
                DaysClimbedRow(
                    weekDays: vm.weekDays,
                    daysClimbed: vm.daysClimbedThisWeek
                )
                if vm.hasPriorWeek {
                    WeekDeltaStrip(
                        sessions: vm.sessionsDelta,
                        gradeLevels: vm.hardestGradeDelta,
                        minutes: vm.durationDeltaMinutes
                    )
                }
                if let wheelhouse = vm.wheelhouse {
                    WheelhouseCard(grade: wheelhouse)
                }
                if let flash = vm.topFlashGrade {
                    FlashCard(flash: flash)
                }
                if vm.hasMultipleGyms, let gym = vm.mostVisitedGym {
                    GymCard(name: gym.name, count: gym.count)
                }
                OutroCTA(
                    shareImage: shareImage,
                    onSeeStats: { dismiss() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 56)
        .onAppear {
            withAnimation(.geckoBounce.delay(0.05)) { heroAppeared = true }
        }
        .task(id: vm.thisWeekSessions.count) {
            shareImage = renderShareImage(vm: vm)
        }
    }

    @MainActor
    private func renderShareImage(vm: WeekInReviewViewModel) -> Image? {
        let card = WeekInReviewShareCard(
            displayName: vm.displayName,
            dateRangeLabel: vm.dateRangeLabel.uppercased(),
            hardestSendLabel: vm.hardestSendLabel,
            hardestSendNumeric: vm.hardestSendNumeric ?? -1,
            isPR: vm.isHardestSendPR,
            totalSessions: vm.totalSessions,
            totalClimbs: vm.totalClimbs,
            totalSends: vm.totalSends,
            totalDurationMinutes: vm.totalDurationMinutes,
            sendRatePercent: Int((vm.sendRate * 100).rounded()),
            weekDays: vm.weekDays,
            daysClimbed: vm.daysClimbedThisWeek,
            wheelhouse: vm.wheelhouse,
            topFlash: vm.topFlashGrade
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = max(displayScale, 3.0)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

// MARK: - Title

private struct TitleCard: View {
    let rangeLabel: String
    let appeared: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("Your Week in Climbing")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color.geckoPrimary)
                .multilineTextAlignment(.center)
            Text(rangeLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .animation(.geckoBounce, value: appeared)
    }
}

// MARK: - Hardest Send Hero

private struct HardestSendCard: View {
    let grade: String
    let numeric: Int
    let isPR: Bool
    let appeared: Bool
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Hardest Send")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.gradeGradient(for: numeric))
                    .frame(width: 200, height: 200)
                    .shadow(color: Color.gradeColor(for: numeric).opacity(0.45),
                            radius: glowPulse ? 30 : 15,
                            x: 0, y: 0)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(.geckoBounce.delay(0.1), value: appeared)

                Text(grade)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(VGrade.textColor(for: numeric))
                    .scaleEffect(appeared ? 1 : 0.2)
                    .opacity(appeared ? 1 : 0)
                    .animation(.geckoBounce.delay(0.25), value: appeared)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            if isPR {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .symbolEffect(.bounce, value: appeared)
                    Text("All-time personal best")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color.geckoFlashGold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.geckoFlashGold.opacity(0.15))
                )
                .overlay(
                    Capsule().stroke(Color.geckoFlashGold.opacity(0.4), lineWidth: 1)
                )
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.geckoBounce.delay(0.5), value: appeared)
            } else if numeric >= 0 {
                Text("Your peak grade this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyleElevated()
    }
}

// MARK: - Volume strip (count-up)

private struct VolumeStrip: View {
    let sessions: Int
    let climbs: Int
    let minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            VolumeTile(
                value: sessions,
                label: "Sessions",
                icon: "figure.climbing",
                tint: .geckoPrimary,
                delay: 0.1
            )
            VolumeTile(
                value: climbs,
                label: "Climbs",
                icon: "mountain.2.fill",
                tint: .geckoOrange,
                delay: 0.25
            )
            VolumeTile(
                value: minutes,
                label: "Minutes",
                icon: "clock.fill",
                tint: .geckoAttemptBlue,
                delay: 0.4
            )
        }
    }
}

private struct VolumeTile: View {
    let value: Int
    let label: String
    let icon: String
    let tint: Color
    let delay: Double

    @State private var displayValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(Int(displayValue), format: .number)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: displayValue))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [tint.opacity(0.08), tint.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
        .cardStyle()
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(delay)) {
                displayValue = Double(value)
            }
        }
    }
}

// MARK: - Send rate ring

private struct SendRateRing: View {
    let sendRate: Double
    let sends: Int
    let total: Int
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Send Rate")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.geckoSentGreen.opacity(0.12), lineWidth: 14)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.geckoSentGreen, Color.geckoPrimary],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress * 100))%")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: animatedProgress))
                    Text("\(sends) of \(total)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                animatedProgress = sendRate
            }
        }
    }
}

// MARK: - Days climbed dot row

private let weekdayLetterFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEEE" // single-letter weekday
    return f
}()

private struct DaysClimbedRow: View {
    let weekDays: [Date]
    let daysClimbed: Set<Date>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Days you climbed")
                .font(.headline.weight(.bold))
            HStack(spacing: 10) {
                ForEach(Array(weekDays.enumerated()), id: \.element) { index, day in
                    DayDot(
                        day: day,
                        isLit: daysClimbed.contains(day),
                        index: index
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cardStyle()
    }
}

private struct DayDot: View {
    let day: Date
    let isLit: Bool
    let index: Int
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isLit ? Color.geckoPrimary : Color.geckoDivider)
                    .frame(width: 32, height: 32)
                if isLit {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(weekdayLetterFormatter.string(from: day))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isLit ? Color.geckoPrimary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(appeared ? 1 : 0.3)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.geckoBounce.delay(0.3 + Double(index) * 0.06)) {
                appeared = true
            }
        }
    }
}

// MARK: - vs last week

private struct WeekDeltaStrip: View {
    let sessions: Int
    let gradeLevels: Int?
    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("vs last week")
                .font(.headline.weight(.bold))
            HStack(spacing: 12) {
                DeltaTile(value: sessions, suffix: "sessions")
                if let g = gradeLevels {
                    DeltaTile(value: g, suffix: g == 1 || g == -1 ? "grade" : "grades", isGrade: true)
                } else {
                    DeltaTile.placeholder("grade")
                }
                DeltaTile(value: minutes, suffix: "min")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .cardStyle()
    }
}

private struct DeltaTile: View {
    let value: Int
    let suffix: String
    var isGrade: Bool = false
    var isPlaceholder: Bool = false

    static func placeholder(_ suffix: String) -> DeltaTile {
        DeltaTile(value: 0, suffix: suffix, isGrade: true, isPlaceholder: true)
    }

    private var arrow: String {
        if isPlaceholder { return "minus" }
        if value > 0 { return "arrow.up.right" }
        if value < 0 { return "arrow.down.right" }
        return "minus"
    }

    private var tint: Color {
        if isPlaceholder { return .secondary }
        if value > 0 { return .geckoSentGreen }
        if value < 0 { return .geckoOrange }
        return .secondary
    }

    private var formatted: String {
        if isPlaceholder { return "—" }
        let abs = Swift.abs(value)
        let prefix = value > 0 ? "+" : (value < 0 ? "−" : "")
        if isGrade { return "\(prefix)\(abs)V" }
        return "\(prefix)\(abs)"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: arrow)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(formatted)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.06))
        )
    }
}

// MARK: - Wheelhouse

private struct WheelhouseCard: View {
    let grade: GradeCount

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.gradeGradient(for: grade.numeric))
                    .frame(width: 70, height: 70)
                    .shadow(color: Color.gradeColor(for: grade.numeric).opacity(0.35),
                            radius: 8, x: 0, y: 4)
                Text(grade.grade)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(VGrade.textColor(for: grade.numeric))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Your wheelhouse")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("\(grade.grade) was your home")
                    .font(.headline.weight(.bold))
                Text("\(grade.count) \(grade.count == 1 ? "send" : "sends") this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Flash highlight

private struct FlashCard: View {
    let flash: GradeCount

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Color.geckoFlashGold)
                .padding(16)
                .background(Circle().fill(Color.geckoFlashGold.opacity(0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Flashes")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("\(flash.count) \(flash.count == 1 ? "flash" : "flashes")")
                    .font(.headline.weight(.bold))
                Text("Hardest: \(flash.grade)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Gym love

private struct GymCard: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.geckoPrimary)
                .padding(16)
                .background(Circle().fill(Color.geckoPrimary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Your home gym this week")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                Text("\(count) \(count == 1 ? "session" : "sessions")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Outro CTA

private struct OutroCTA: View {
    let shareImage: Image?
    let onSeeStats: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Keep climbing.")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.geckoPrimary)
                Text("Your story is just getting started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let shareImage {
                ShareLink(
                    item: shareImage,
                    subject: Text("My week in climbing"),
                    message: Text("My climbing week with Gecko"),
                    preview: SharePreview(
                        "Your week in climbing",
                        image: shareImage
                    )
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share my week")
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(Color.geckoPrimary))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .bouncePress()
            }

            Button(action: onSeeStats) {
                HStack(spacing: 6) {
                    Text("See full stats")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Color.geckoPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Empty states

/// Returning climber — has lifetime activity but didn't climb in the past 7 days.
/// Surfaces lifetime context so the screen still earns its keep.
private struct EmptyReturning: View {
    let vm: WeekInReviewViewModel
    let onClose: () -> Void
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                rangeBadge
                gapHero
                lifetimeStripView
                nudgeFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.geckoBounce.delay(0.05)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var rangeBadge: some View {
        Text(vm.dateRangeLabel.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Color.geckoPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.geckoPrimary.opacity(0.12)))
            .padding(.top, 8)
    }

    private var gapHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.geckoPrimary.opacity(0.10))
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulse ? 1.04 : 0.98)
                Circle()
                    .fill(Color.geckoPrimary.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                Image(systemName: "figure.climbing")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color.geckoPrimary)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            Text("No climbs this week")
                .font(.system(size: 22, weight: .black, design: .rounded))

            Text(daysCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var daysCopy: String {
        guard let days = vm.daysSinceLastSession else {
            return "Log a session to start your next story."
        }
        switch days {
        case 0:
            return "You climbed earlier today — refresh after your next session."
        case 1:
            return "Last climb was yesterday. Time for round two?"
        case 2...6:
            return "Last climb was \(days) days ago. The wall misses you."
        case 7...13:
            return "It's been over a week. Time to get back on the wall."
        default:
            return "It's been \(days) days. Your projects are waiting."
        }
    }

    private var lifetimeStripView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where you stand")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                LifetimeTile(
                    label: "Top grade",
                    value: vm.lifetimeHardestGrade,
                    tint: Color.gradeColor(for: vm.allTimeHighestGradeNumeric),
                    big: true
                )
                LifetimeTile(
                    label: "Sessions",
                    value: "\(vm.lifetimeTotalSessions)",
                    tint: .geckoPrimary
                )
                LifetimeTile(
                    label: "Climbs",
                    value: "\(vm.lifetimeTotalClimbs)",
                    tint: .geckoOrange
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var nudgeFooter: some View {
        VStack(spacing: 14) {
            Text("Your next chapter starts on the wall.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onClose) {
                HStack(spacing: 6) {
                    Text("See full stats")
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "chart.bar.fill")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.geckoPrimary))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .bouncePress()
        }
        .padding(.top, 8)
    }
}

/// Tile used in the empty-state lifetime strip. Variant `big` emphasizes the grade.
private struct LifetimeTile: View {
    let label: String
    let value: String
    let tint: Color
    var big: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: big ? 26 : 20, weight: .black, design: .rounded))
                .foregroundStyle(big ? tint : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.08))
        )
    }
}

/// First-time climber — no sessions ever logged. Pure onboarding card.
private struct EmptyFirstTimer: View {
    let onClose: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.geckoMint.opacity(0.5))
                    .frame(width: 140, height: 140)
                Image(systemName: "sparkles")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(Color.geckoPrimary)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Your story starts here")
                    .font(.system(size: 22, weight: .black, design: .rounded))

                Text("Log a climbing session and your week-in-review unlocks — hardest send, send rate, days you climbed, all of it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button(action: onClose) {
                Text("Got it")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.geckoPrimary))
            }
            .buttonStyle(.plain)
            .bouncePress()
            .padding(.top, 4)
        }
        .padding(40)
        .onAppear {
            withAnimation(.geckoBounce.delay(0.1)) { appeared = true }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WeekInReviewView()
    }
    .environment(AppEnvironment.preview)
    .environment(AppEnvironment.previewAuth(.preview))
}
#endif
