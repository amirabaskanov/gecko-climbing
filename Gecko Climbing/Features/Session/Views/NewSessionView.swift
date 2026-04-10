import SwiftUI
import SwiftData

struct NewSessionView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: NewSessionViewModel?
    @State private var finishedSession: SessionModel?
    @State private var showCelebration = false
    @State private var showRestoredBanner = false

    // Inline climb logger state
    @AppStorage("lastSelectedGrade") private var selectedGrade = "V5"
    @State private var showAttemptSelector = false
    @State private var attemptSelectorOutcome: ClimbOutcome = .sent
    @State private var showCancelConfirmation = false
    @State private var lastLoggedOutcome: ClimbOutcome?
    @State private var userAllTimeBestGrade: Int = -1
    @State private var showNewPBBanner = false
    @State private var newPBGrade: String = ""

    // Timer (tick every second for m:ss display)
    @State private var timerTick = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Bindings for tab bar integration
    @Binding var climbCount: Int
    var finishTrigger: UUID

    var onSessionSaved: ((SessionModel) -> Void)?
    var onCancel: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    sessionContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let vm = viewModel, !vm.climbs.isEmpty {
                            showCancelConfirmation = true
                        } else {
                            if let onCancel { onCancel() } else { dismiss() }
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .principal) {
                    if let vm = viewModel {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(vm.elapsedTimeFormatted)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .id(timerTick)
                    }
                }
            }
            .alert("Discard Session?", isPresented: $showCancelConfirmation) {
                Button("Discard", role: .destructive) {
                    viewModel?.clearDraft()
                    if let onCancel { onCancel() } else { dismiss() }
                }
                Button("Keep Logging", role: .cancel) { }
            } message: {
                Text("You have \(viewModel?.climbs.count ?? 0) climbs that will be lost.")
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = NewSessionViewModel(
                    sessionRepository: appEnv.sessionRepository,
                    userId: authViewModel.currentUserId
                )
                if let draft = NewSessionViewModel.loadDraft(userId: authViewModel.currentUserId), !draft.climbs.isEmpty {
                    vm.restoreFromDraft(draft)
                    showRestoredBanner = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                        withAnimation(.geckoSnappy) { showRestoredBanner = false }
                    }
                }
                viewModel = vm
            }
            // Fetch user's all-time best for PB detection
            if userAllTimeBestGrade == -1 {
                Task {
                    if let user = try? await appEnv.userRepository.fetchUser(uid: authViewModel.currentUserId) {
                        userAllTimeBestGrade = user.highestGradeNumeric
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            timerTick = Date()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel?.persistDraft()
            }
        }
        .onChange(of: viewModel?.climbs.count) { _, newCount in
            climbCount = newCount ?? 0
        }
        .onChange(of: finishTrigger) {
            if let vm = viewModel, !vm.climbs.isEmpty {
                finishSession(vm)
            }
        }
        .sheet(isPresented: $showCelebration, onDismiss: {
            if let session = finishedSession {
                onSessionSaved?(session)
                finishedSession = nil
            }
        }) {
            if let vm = viewModel, let session = finishedSession {
                CelebrationView(
                    session: session,
                    viewModel: vm,
                    modelContext: modelContext,
                    appEnv: appEnv,
                    userDisplayName: authViewModel.currentUserDisplayName,
                    userProfileImageURL: ""
                ) { savedSession, post in
                    Task {
                        if let savedSession {
                            finishedSession = savedSession
                        }
                        if let post {
                            do {
                                try await appEnv.postRepository.createPost(post)
                            } catch {
                                // Session is already saved to Firestore — the failure
                                // is on the feed-post side. Surface it through the VM
                                // and KEEP the celebration sheet up so the user sees
                                // the alert and the session isn't silently orphaned.
                                vm.error = error
                                return
                            }
                        }
                        showCelebration = false
                    }
                }
                .errorAlert(error: Binding(
                    get: { vm.error },
                    set: { vm.error = $0 }
                ))
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func sessionContent(_ vm: NewSessionViewModel) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Zone A: Grade barrel + outcome buttons (pinned)
                pinnedLogger(vm)

                // Zone B: Climb list + stats
                ScrollViewReader { proxy in
                    List {
                        // Restored-session banner (shown briefly after reopen)
                        if showRestoredBanner {
                            restoredBanner
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        // New PB banner
                        if showNewPBBanner {
                            newPBBanner
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        // Climb milestone banner
                        if vm.climbs.count >= 5 {
                            climbMilestoneBanner(count: vm.climbs.count)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        // Stats bar
                        if !vm.climbs.isEmpty {
                            sessionStatsBar(vm)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        // Climb rows
                        ForEach(Array(vm.climbs.enumerated()), id: \.element.climbId) { index, climb in
                            ClimbRowView(climb: climb, index: index)
                                .id(climb.climbId)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .slide
                                ))
                        }
                        .onDelete { offsets in
                            withAnimation(.geckoSpring) { vm.removeClimb(at: offsets) }
                        }
                        .onMove { source, destination in
                            withAnimation(.geckoSpring) { vm.moveClimb(from: source, to: destination) }
                        }

                        if vm.climbs.isEmpty {
                            emptyState
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }

                        // Bottom spacer for tab bar
                        Color.clear
                            .frame(height: 20)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.geckoBackground)
                    .onChange(of: vm.climbs.count) {
                        if let firstClimb = vm.climbs.first {
                            withAnimation {
                                proxy.scrollTo(firstClimb.climbId, anchor: .top)
                            }
                        }
                    }
                }
            }

        }
        .background(Color.geckoBackground)
        .animation(.geckoSpring, value: vm.climbs.count)
    }

    // MARK: - Pinned Logger

    private func pinnedLogger(_ vm: NewSessionViewModel) -> some View {
        VStack(spacing: 12) {
            // Grade barrel picker (tall)
            GradeBarrelView(selectedGrade: $selectedGrade)

            // Three outcome buttons
            outcomeButtons(vm)

            // Attempt selector (Sent or Attempted)
            if showAttemptSelector {
                AttemptBubbleSelector(
                    accentColor: attemptSelectorOutcome.color,
                    minimumAttempts: attemptSelectorOutcome == .attempt ? 1 : 2
                ) { attempts in
                    withAnimation(.geckoSnappy) {
                        showAttemptSelector = false
                    }
                    logClimb(vm: vm, outcome: attemptSelectorOutcome, attempts: attempts)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(Color.geckoCard)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Three Outcome Buttons

    private func outcomeButtons(_ vm: NewSessionViewModel) -> some View {
        HStack(spacing: 10) {
            outcomeButton(outcome: .flash, icon: "bolt.fill", label: "FLASH", subtitle: "1 try", vm: vm)
            outcomeButton(outcome: .sent, icon: "checkmark", label: "SENT", subtitle: nil, vm: vm)
            outcomeButton(outcome: .attempt, icon: "arrow.trianglehead.counterclockwise", label: "ATTEMPT", subtitle: nil, vm: vm)
        }
    }

    private func outcomeButton(outcome: ClimbOutcome, icon: String, label: String, subtitle: String?, vm: NewSessionViewModel) -> some View {
        Button {
            handleOutcomeTap(outcome, vm: vm)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(outcome.color.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .foregroundStyle(outcome.color)
            .background(outcome.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(outcome.color.opacity(outcome == .flash ? 0.6 : 0.3), lineWidth: outcome == .flash ? 2 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .bouncePress()
        .sensoryFeedback(.impact(flexibility: outcome == .flash ? .rigid : outcome == .sent ? .solid : .soft,
                                  intensity: outcome == .flash ? 0.9 : outcome == .sent ? 0.7 : 0.4),
                          trigger: lastLoggedOutcome.map { $0 == outcome } ?? false)
    }

    // MARK: - Session Stats Bar

    @State private var statsPopTrigger = 0

    private func sessionStatsBar(_ vm: NewSessionViewModel) -> some View {
        HStack(spacing: 12) {
            if vm.flashes.count > 0 {
                statChip(icon: "bolt.fill", count: vm.flashes.count, color: .geckoFlashGold)
                    .transition(.scale.combined(with: .opacity))
            }
            statChip(icon: "checkmark.circle.fill", count: vm.sends.count + vm.flashes.count, color: .geckoPrimary)
            if vm.attempts.count > 0 {
                statChip(icon: "arrow.trianglehead.counterclockwise", count: vm.attempts.count, color: .geckoAttemptBlue)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Text("Total: \(vm.climbs.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.geckoSnappy, value: vm.climbs.count)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.geckoPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect(statsPopTrigger > 0 ? 1.0 : 1.0)
        .onChange(of: vm.climbs.count) {
            withAnimation(.geckoSnappy) {
                statsPopTrigger += 1
            }
        }
    }

    private func statChip(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: count)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.geckoSnappy, value: count)
        }
    }

    // MARK: - Climb Milestone Banner

    private func climbMilestoneBanner(count: Int) -> some View {
        let message: String = switch count {
        case 5..<10:  "\(count) climbs — nice session!"
        case 10..<15: "\(count) climbs — on fire!"
        case 15..<20: "\(count) climbs — crushing it!"
        default:      "\(count) climbs — beast mode!"
        }

        return HStack(spacing: 6) {
            Text("\u{1F525}")
            Text(message)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.geckoPrimary)
                .contentTransition(.numericText())
                .animation(.geckoSnappy, value: count)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.geckoPrimary.opacity(0.1), in: Capsule())
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Restored Session Banner

    private var restoredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.geckoPrimary)
            Text("Picked up where you left off")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Button {
                withAnimation(.geckoSnappy) { showRestoredBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.geckoPrimary.opacity(0.1), in: Capsule())
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - New PB Banner

    private var newPBBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(Color.geckoFlashGold)
                .symbolEffect(.bounce, value: showNewPBBanner)
            VStack(alignment: .leading, spacing: 2) {
                Text("New Personal Best!")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.primary)
                Text("\(newPBGrade) — you've never sent this grade before!")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.geckoFlashGold.opacity(0.15), Color.geckoFlashGold.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.geckoFlashGold.opacity(0.3), lineWidth: 1)
        )
        .transition(.scale.combined(with: .opacity))
        .sensoryFeedback(.success, trigger: showNewPBBanner)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            GeckoLogoView(size: 44, color: .geckoPrimary.opacity(0.4))

            Text("Scroll a grade, tap an outcome!")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Image(systemName: "arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Outcome Tap Handler

    private func handleOutcomeTap(_ outcome: ClimbOutcome, vm: NewSessionViewModel) {
        switch outcome {
        case .flash:
            logClimb(vm: vm, outcome: .flash, attempts: 1)

        case .sent:
            withAnimation(.geckoSnappy) {
                attemptSelectorOutcome = .sent
                showAttemptSelector = true
            }

        case .attempt:
            withAnimation(.geckoSnappy) {
                attemptSelectorOutcome = .attempt
                showAttemptSelector = true
            }
        }
    }

    // MARK: - Log Climb

    private func logClimb(vm: NewSessionViewModel, outcome: ClimbOutcome, attempts: Int) {
        lastLoggedOutcome = outcome

        // Check for all-time Personal Best (only for completed climbs)
        if outcome.isCompleted && userAllTimeBestGrade >= 0 {
            let gradeNumeric = VGrade.numeric(for: selectedGrade)
            if gradeNumeric > userAllTimeBestGrade {
                userAllTimeBestGrade = gradeNumeric
                newPBGrade = selectedGrade
                withAnimation(.geckoSpring) { showNewPBBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.geckoSnappy) { showNewPBBanner = false }
                }
            }
        }

        withAnimation(.geckoSpring) {
            vm.addClimb(grade: selectedGrade, outcome: outcome, attempts: attempts)
        }
    }

    // MARK: - Finish Session

    private func finishSession(_ vm: NewSessionViewModel) {
        let tempSession = SessionModel(
            userId: authViewModel.currentUserId,
            gymName: vm.gymName.isEmpty ? "Session" : vm.gymName,
            date: vm.date,
            durationMinutes: vm.elapsedMinutes,
            startedAt: vm.sessionStartedAt
        )
        // Preserve loggedAt so the celebration summary and the resulting feed
        // post see the climbs in the order they were actually logged.
        for climb in vm.climbs {
            let c = ClimbModel(
                sessionId: tempSession.sessionId,
                grade: climb.grade,
                gradeNumeric: climb.gradeNumeric,
                outcome: climb.climbOutcome,
                attempts: climb.attempts,
                loggedAt: climb.loggedAt
            )
            tempSession.climbs.append(c)
        }
        tempSession.updateStats()

        finishedSession = tempSession
        showCelebration = true
    }
}
