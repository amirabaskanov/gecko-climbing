import SwiftUI
import SwiftData

struct NewSessionView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: NewSessionViewModel?
    @State private var finishedSession: SessionModel?
    @State private var showCelebration = false

    // Inline climb logger state
    @State private var selectedGrade = "V5"
    @State private var showAttemptSelector = false
    @State private var attemptSelectorOutcome: ClimbOutcome = .sent
    @State private var showCancelConfirmation = false
    @State private var lastLoggedOutcome: ClimbOutcome?

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
                }
                ToolbarItem(placement: .principal) {
                    if let vm = viewModel {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(vm.elapsedTimeFormatted)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .id(timerTick)
                    }
                }
            }
            .alert("Discard Session?", isPresented: $showCancelConfirmation) {
                Button("Discard", role: .destructive) {
                    if let onCancel { onCancel() } else { dismiss() }
                }
                Button("Keep Logging", role: .cancel) { }
            } message: {
                Text("You have \(viewModel?.climbs.count ?? 0) climbs that will be lost.")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = NewSessionViewModel(
                    sessionRepository: appEnv.sessionRepository,
                    userId: authViewModel.currentUserId
                )
            }
        }
        .onReceive(timer) { _ in
            timerTick = Date()
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
                    appEnv: appEnv
                ) { savedSession, post in
                    Task {
                        if let post {
                            try? await appEnv.postRepository.createPost(post)
                        }
                        if let savedSession {
                            finishedSession = savedSession
                        }
                        showCelebration = false
                    }
                }
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
                        // Streak banner
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
                    .background(Color.surfaceBackground)
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
        .background(Color.surfaceBackground)
        .animation(.geckoSpring, value: vm.climbs.count)
    }

    // MARK: - Pinned Logger

    private func pinnedLogger(_ vm: NewSessionViewModel) -> some View {
        VStack(spacing: 14) {
            // Grade barrel picker (tall)
            GradeBarrelView(selectedGrade: $selectedGrade)

            // Three outcome buttons
            outcomeButtons(vm)

            // Attempt selector (Sent or Attempted)
            if showAttemptSelector {
                AttemptBubbleSelector(accentColor: attemptSelectorOutcome.color) { attempts in
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
        .background(Color.surface)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
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
                        .foregroundColor(outcome.color.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .foregroundColor(outcome.color)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(outcome.color.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .bouncePress()
        .sensoryFeedback(.impact(flexibility: outcome == .flash ? .rigid : outcome == .sent ? .solid : .soft,
                                  intensity: outcome == .flash ? 0.9 : outcome == .sent ? 0.7 : 0.4),
                          trigger: lastLoggedOutcome.map { $0 == outcome } ?? false)
    }

    // MARK: - Session Stats Bar

    private func sessionStatsBar(_ vm: NewSessionViewModel) -> some View {
        HStack(spacing: 14) {
            if vm.flashes.count > 0 {
                statChip(icon: "bolt.fill", count: vm.flashes.count, color: .geckoFlashGold)
            }
            statChip(icon: "checkmark.circle.fill", count: vm.sends.count + vm.flashes.count, color: .geckoGreen)
            if vm.attempts.count > 0 {
                statChip(icon: "arrow.trianglehead.counterclockwise", count: vm.attempts.count, color: .geckoAttemptBlue)
            }

            Spacer()

            Text("Total: \(vm.climbs.count)")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
                .contentTransition(.numericText())
                .animation(.geckoSnappy, value: vm.climbs.count)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.geckoGreen.opacity(0.06))
    }

    private func statChip(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundColor(color)
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
                .foregroundStyle(Color.geckoGreen)
                .contentTransition(.numericText())
                .animation(.geckoSnappy, value: count)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.geckoGreen.opacity(0.1), in: Capsule())
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.climbing")
                .font(.system(size: 44))
                .foregroundColor(Color.geckoGreen.opacity(0.4))

            Text("Scroll a grade, tap an outcome!")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Image(systemName: "arrow.up")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
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

        default:
            break
        }
    }

    // MARK: - Log Climb

    private func logClimb(vm: NewSessionViewModel, outcome: ClimbOutcome, attempts: Int) {
        lastLoggedOutcome = outcome
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
        for climb in vm.climbs {
            let c = ClimbModel(
                sessionId: tempSession.sessionId,
                grade: climb.grade,
                gradeNumeric: climb.gradeNumeric,
                outcome: climb.climbOutcome,
                attempts: climb.attempts
            )
            tempSession.climbs.append(c)
        }
        tempSession.updateStats()

        finishedSession = tempSession
        showCelebration = true
    }
}
