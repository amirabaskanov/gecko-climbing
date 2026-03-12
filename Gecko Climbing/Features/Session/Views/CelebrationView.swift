import SwiftUI
import SwiftData

struct CelebrationView: View {
    let session: SessionModel
    let viewModel: NewSessionViewModel
    let modelContext: ModelContext
    let appEnv: AppEnvironment
    let onDone: (SessionModel?, PostModel?) -> Void

    @State private var caption = ""
    @State private var animateIn = false
    @State private var showConfetti = false
    @State private var showDetailsForm = false
    @State private var recentGyms: [String] = []

    // Form bindings that sync to viewModel
    @State private var gymName = ""
    @State private var sessionDate = Date()
    @State private var durationMinutes = 0
    @State private var notes = ""

    var body: some View {
        celebrationScreen
    }

    private var celebrationScreen: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: showDetailsForm
                    ? [Color.surfaceBackground, Color.surfaceBackground]
                    : [Color.geckoGreen, Color.geckoGreenDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.5), value: showDetailsForm)

            if showDetailsForm {
                // Phase 2: Details form
                ScrollView {
                    SessionDetailsForm(
                        climbCount: session.totalClimbs,
                        autoMinutes: viewModel.elapsedMinutes,
                        gymName: $gymName,
                        date: $sessionDate,
                        durationMinutes: $durationMinutes,
                        notes: $notes,
                        caption: $caption,
                        recentGyms: recentGyms,
                        onSave: { saveAndShare() }
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // Phase 1: Celebration
                celebrationContent
            }

            // Confetti overlay
            ConfettiView(isActive: $showConfetti)
                .ignoresSafeArea()
        }
        .onAppear {
            gymName = viewModel.gymName
            sessionDate = viewModel.date
            notes = viewModel.notes
            animateIn = true
            loadRecentGyms()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
            // Auto-transition to details form after celebration
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.geckoSpring) {
                    showDetailsForm = true
                }
            }
        }
    }

    private var celebrationContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Checkmark icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 76))
                .foregroundColor(.white)
                .scaleEffect(animateIn ? 1.0 : 0.2)
                .opacity(animateIn ? 1 : 0)
                .animation(.geckoBounce.delay(0.3), value: animateIn)

            // Title + climb count
            VStack(spacing: 8) {
                Text("Session Complete!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("\(session.totalClimbs) climbs")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: animateIn)

            // Stats cards with animated counters
            HStack(spacing: 10) {
                if session.flashCount > 0 {
                    celebrationStat(
                        target: session.flashCount,
                        label: "Flashes",
                        delay: 0.5,
                        accentColor: .geckoFlashGold
                    )
                }
                celebrationStat(
                    target: session.completedClimbs,
                    label: "Sends",
                    delay: 0.6,
                    accentColor: .geckoSentGreenLight
                )
                celebrationStat(
                    target: session.totalClimbs,
                    label: "Climbs",
                    delay: 0.7
                )
                if viewModel.elapsedMinutes > 0 {
                    celebrationStatText(
                        value: viewModel.elapsedMinutes.durationFormatted,
                        label: "Duration",
                        delay: 0.75
                    )
                }
                if !session.highestGrade.isEmpty {
                    celebrationStatText(
                        value: session.highestGrade,
                        label: "Top Send",
                        delay: 0.8
                    )
                }
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
    }

    private func celebrationStat(target: Int, label: String, delay: Double, accentColor: Color = .white) -> some View {
        VStack(spacing: 4) {
            AnimatedCounter(
                target: target,
                duration: 0.8,
                delay: delay,
                font: .system(size: 18, weight: .black, design: .rounded),
                color: accentColor
            )
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 16)
        .animation(.geckoSpring.delay(delay), value: animateIn)
    }

    private func celebrationStatText(value: String, label: String, delay: Double) -> some View {
        VStack(spacing: 4) {
            AnimatedCounterText(
                value: value,
                delay: delay,
                font: .system(size: 18, weight: .black, design: .rounded),
                color: .white
            )
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 16)
        .animation(.geckoSpring.delay(delay), value: animateIn)
    }

    // MARK: - Save Actions

    private func saveAndShare() {
        viewModel.gymName = gymName
        viewModel.date = sessionDate
        viewModel.durationMinutes = durationMinutes > 0 ? durationMinutes % 60 : viewModel.elapsedMinutes % 60
        viewModel.durationHours = durationMinutes > 0 ? durationMinutes / 60 : viewModel.elapsedMinutes / 60
        viewModel.notes = notes

        Task {
            if let saved = await viewModel.saveSession(context: modelContext) {
                let gradeCounts = Dictionary(
                    grouping: saved.climbs.filter { $0.climbOutcome.isCompleted },
                    by: { $0.grade }
                ).mapValues { $0.count }

                let post = PostModel(
                    userId: saved.userId,
                    sessionId: saved.sessionId,
                    gymName: saved.gymName,
                    caption: caption,
                    topGrade: saved.highestGrade,
                    topGradeNumeric: saved.highestGradeNumeric,
                    totalClimbs: saved.totalClimbs,
                    gradeCounts: gradeCounts
                )
                onDone(saved, post)
            }
        }
    }

    private func loadRecentGyms() {
        let descriptor = FetchDescriptor<SessionModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let sessions = try? modelContext.fetch(descriptor) {
            let gyms = sessions.map(\.gymName).filter { !$0.isEmpty }
            var seen = Set<String>()
            recentGyms = gyms.filter { seen.insert($0).inserted }.prefix(5).map { $0 }
        }
    }

}
