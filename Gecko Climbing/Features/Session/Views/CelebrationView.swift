import SwiftUI
import SwiftData
import PhotosUI

struct CelebrationView: View {
    let session: SessionModel
    let viewModel: NewSessionViewModel
    let modelContext: ModelContext
    let appEnv: AppEnvironment
    let userDisplayName: String
    let userProfileImageURL: String
    let onDone: (SessionModel?, PostModel?) -> Void

    @State private var caption = ""
    @State private var animateIn = false
    @State private var showConfetti = false
    @State private var showDetailsForm = false
    @State private var showInsights = false
    @State private var recentGyms: [String] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var isSaving = false
    @State private var insights: [SessionInsight] = []

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
                    ? [Color.geckoBackground, Color.geckoBackground]
                    : [Color.geckoPrimary, Color.geckoPrimaryDark],
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
                        selectedPhotos: $selectedPhotos,
                        photoImages: $photoImages,
                        recentGyms: recentGyms,
                        isSaving: isSaving,
                        onSave: { saveAndShare() }
                    )
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    Task { await loadPhotos(from: newItems) }
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
            loadInsights()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
            // Show insights after celebration stats settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.geckoSpring) {
                    showInsights = true
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
                .foregroundStyle(.white)
                .scaleEffect(animateIn ? 1.0 : 0.2)
                .opacity(animateIn ? 1 : 0)
                .animation(.geckoBounce.delay(0.3), value: animateIn)

            // Title + climb count
            VStack(spacing: 8) {
                Text("Session Complete!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(session.totalClimbs) climbs")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: animateIn)

            // Stats cards with animated counters
            HStack(spacing: 10) {
                celebrationStat(label: "Climbs", delay: 0.5, count: session.totalClimbs)
                if session.flashCount > 0 {
                    celebrationStat(label: "Flashes", delay: 0.6, accentColor: .geckoFlashGold, count: session.flashCount)
                }
                celebrationStat(label: "Sends", delay: 0.7, accentColor: .geckoSentGreenLight, count: session.completedClimbs)
                if viewModel.elapsedMinutes > 0 {
                    celebrationStat(label: "Duration", delay: 0.75, text: viewModel.elapsedMinutes.durationFormatted)
                }
                if !session.highestGrade.isEmpty {
                    celebrationStat(label: "Top Send", delay: 0.8, text: session.highestGrade)
                }
            }
            .padding(.horizontal, 8)

            // Insights
            if showInsights && !insights.isEmpty {
                insightsSection
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Spacer()

            // Manual continue button
            Button {
                withAnimation(.geckoSpring) {
                    showDetailsForm = true
                }
            } label: {
                Text("Continue")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.2), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut.delay(1.0), value: animateIn)
        }
    }

    /// Stat chip in the celebration screen. Pass `count` for numeric stats
    /// (animated counter) or `text` for string values like a grade or duration.
    @ViewBuilder
    private func celebrationStat(label: String,
                                 delay: Double,
                                 accentColor: Color = .white,
                                 count: Int? = nil,
                                 text: String? = nil) -> some View {
        VStack(spacing: 4) {
            if let count {
                AnimatedCounter(
                    target: count,
                    duration: 0.8,
                    delay: delay,
                    font: .system(size: 18, weight: .black, design: .rounded),
                    color: accentColor
                )
            } else if let text {
                AnimatedCounterText(
                    value: text,
                    delay: delay,
                    font: .system(size: 18, weight: .black, design: .rounded),
                    color: accentColor
                )
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
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
        guard !isSaving else { return }
        isSaving = true

        viewModel.gymName = gymName
        viewModel.date = sessionDate
        viewModel.durationMinutes = durationMinutes > 0 ? durationMinutes % 60 : viewModel.elapsedMinutes % 60
        viewModel.durationHours = durationMinutes > 0 ? durationMinutes / 60 : viewModel.elapsedMinutes / 60
        viewModel.notes = notes

        Task {
            if let saved = await viewModel.saveSession(context: modelContext) {
                // Upload photos
                var uploadedURLs: [String] = []
                for image in photoImages {
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        do {
                            let url = try await appEnv.storageRepository.uploadSessionPhoto(
                                userId: saved.userId,
                                sessionId: saved.sessionId,
                                imageData: data
                            )
                            uploadedURLs.append(url)
                        } catch {
                            // Continue with remaining photos
                        }
                    }
                }

                // Chronological (oldest → newest) so the feed renders in logging order.
                let orderedClimbs = saved.climbs.sorted { $0.loggedAt < $1.loggedAt }
                let completedClimbs = orderedClimbs.filter { $0.climbOutcome.isCompleted }
                let gradeCounts = Dictionary(
                    grouping: completedClimbs,
                    by: { $0.grade }
                ).mapValues { $0.count }
                // Include attempts too so the feed can render them with a different texture.
                let gradeSequence = orderedClimbs.map(\.grade)
                let outcomeSequence = orderedClimbs.map { $0.climbOutcome.rawValue }

                let post = PostModel(
                    userId: saved.userId,
                    userDisplayName: userDisplayName,
                    userProfileImageURL: userProfileImageURL,
                    sessionId: saved.sessionId,
                    gymName: saved.gymName,
                    caption: caption,
                    imageURL: uploadedURLs.first,
                    imageURLs: uploadedURLs,
                    topGrade: saved.highestGrade,
                    topGradeNumeric: saved.highestGradeNumeric,
                    totalClimbs: saved.totalClimbs,
                    gradeCounts: gradeCounts,
                    gradeSequence: gradeSequence,
                    outcomeSequence: outcomeSequence
                )
                onDone(saved, post)
            }
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        await MainActor.run {
            photoImages = images
        }
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                insightCard(insight, index: index)
            }
        }
    }

    private func insightCard(_ insight: SessionInsight, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(insight.accentColor)
                .frame(width: 36, height: 36)
                .background(insight.accentColor.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(showInsights ? 1 : 0)
        .offset(y: showInsights ? 0 : 12)
        .animation(.geckoSpring.delay(Double(index) * 0.12), value: showInsights)
    }

    // MARK: - Data Loading

    private func loadInsights() {
        let descriptor = FetchDescriptor<SessionModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let history = try? modelContext.fetch(descriptor) {
            insights = SessionInsightsEngine.generate(current: session, history: history)
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
