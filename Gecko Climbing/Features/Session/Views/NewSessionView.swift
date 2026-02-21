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
    @State private var selectedOutcome: ClimbOutcome = .sent
    @State private var attempts = 2
    @State private var showDetails = false
    @State private var lastLoggedClimbId: String?
    @State private var showCancelConfirmation = false

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
            .navigationTitle("Log Session")
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
                ToolbarItem(placement: .confirmationAction) {
                    if let vm = viewModel {
                        Button("Save") {
                            saveSession(vm)
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSave(vm))
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
        .sheet(isPresented: $showCelebration, onDismiss: {
            if let session = finishedSession {
                onSessionSaved?(session)
                finishedSession = nil
            }
        }) {
            if let session = finishedSession {
                CelebrationView(session: session) { post in
                    Task {
                        if let post {
                            try? await appEnv.postRepository.createPost(post)
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
        VStack(spacing: 0) {
            // Zone A: Pinned logger (never scrolls)
            pinnedLogger(vm)

            // Zone B: Scrollable list (sole scroll container)
            ScrollViewReader { proxy in
                List {
                    // Header
                    if !vm.climbs.isEmpty {
                        climbsHeader(vm)
                    }

                    // Climb rows with native swipe-to-delete
                    ForEach(vm.climbs) { climb in
                        ClimbRowView(climb: climb)
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
                        withAnimation(.bouncy) { vm.removeClimb(at: offsets) }
                    }

                    // Session details section
                    sessionDetailsSection(vm)

                    // Save button (bottom of list)
                    saveButtonRow(vm)

                    // Empty state when no climbs
                    if vm.climbs.isEmpty {
                        emptyState
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.geckoBackground)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.climbs.count) {
                    if let firstClimb = vm.climbs.first {
                        withAnimation {
                            proxy.scrollTo(firstClimb.climbId, anchor: .top)
                        }
                    }
                }
            }
        }
        .background(Color.geckoBackground)
    }

    // MARK: - Pinned Logger (Zone A)

    private func pinnedLogger(_ vm: NewSessionViewModel) -> some View {
        VStack(spacing: 10) {
            // Compact gym name field
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color.geckoGreen)
                    .font(.system(size: 18))
                TextField("Where are you climbing?", text: Binding(
                    get: { vm.gymName },
                    set: { vm.gymName = $0 }
                ))
                .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.geckoBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Grade chips (horizontal snapping scroll)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(VGrade.standard, id: \.self) { grade in
                        GradeChip(grade: grade, isSelected: selectedGrade == grade) {
                            withAnimation(.bouncy) { selectedGrade = grade }
                        }
                        .id(grade)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(
                get: { Optional(selectedGrade) },
                set: { if let g = $0 { selectedGrade = g } }
            ))
            .scrollIndicators(.hidden)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: selectedGrade)

            // 2×2 outcome button grid
            outcomeGrid(vm)

            // Stepper + Log button (non-flash only)
            if selectedOutcome != .flash {
                stepperAndLogButton(vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        .sensoryFeedback(.success, trigger: vm.climbs.count)
        .overlay(alignment: .bottom) {
            if lastLoggedClimbId != nil {
                Text("Logged!")
                    .font(.caption.weight(.black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.geckoGreen, in: Capsule())
                    .phaseAnimator([false, true], trigger: lastLoggedClimbId) { content, phase in
                        content
                            .opacity(phase ? 0 : 1)
                            .offset(y: phase ? 20 : 8)
                            .scaleEffect(phase ? 0.8 : 1.0)
                    } animation: { phase in
                        phase ? .easeIn(duration: 0.6).delay(0.5) : .bouncy(duration: 0.3)
                    }
            }
        }
    }

    // MARK: - 2×2 Outcome Grid

    private func outcomeGrid(_ vm: NewSessionViewModel) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ClimbOutcome.allCases) { outcome in
                Button {
                    handleOutcomeTap(outcome, vm: vm)
                } label: {
                    let isSelected = selectedOutcome == outcome
                    HStack(spacing: 6) {
                        Image(systemName: outcome.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(outcome.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? outcome.color : outcome.color.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : outcome.color.opacity(0.25), lineWidth: 1.5)
                    )
                    .foregroundColor(isSelected ? .white : outcome.color)
                    .scaleEffect(isSelected ? 1.04 : 1.0)
                    .animation(.bouncy(duration: 0.3), value: selectedOutcome)
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: selectedOutcome)
    }

    // MARK: - Stepper + Log Button

    private func stepperAndLogButton(_ vm: NewSessionViewModel) -> some View {
        HStack(spacing: 12) {
            // Stepper
            HStack(spacing: 10) {
                Button {
                    if attempts > selectedOutcome.minAttempts { attempts -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(attempts > selectedOutcome.minAttempts ? selectedOutcome.color : .gray.opacity(0.3))
                }
                .disabled(attempts <= selectedOutcome.minAttempts)

                Text("\(attempts)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: attempts)
                    .frame(minWidth: 28)

                Button {
                    attempts += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(selectedOutcome.color)
                }
            }
            .frame(width: 120)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: attempts)

            // Log button
            Button {
                logClimb(vm: vm, outcome: selectedOutcome, attempts: attempts)
            } label: {
                Text("Log \(selectedOutcome.label)")
                    .font(.callout.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(selectedOutcome.color)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Climbs Header

    private func climbsHeader(_ vm: NewSessionViewModel) -> some View {
        HStack {
            Text("Climbs (\(vm.climbs.count))")
                .font(.headline)
            Spacer()
            Text(vm.climbSummaryText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Session Details (collapsible)

    private func sessionDetailsSection(_ vm: NewSessionViewModel) -> some View {
        DisclosureGroup(isExpanded: $showDetails) {
            VStack(spacing: 12) {
                HStack {
                    Label("Date", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    DatePicker("", selection: Binding(
                        get: { vm.date },
                        set: { vm.date = $0 }
                    ), displayedComponents: [.date])
                    .labelsHidden()
                }

                HStack {
                    Label("Duration", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { vm.durationHours },
                        set: { vm.durationHours = $0 }
                    )) {
                        ForEach(0...8, id: \.self) { Text("\($0)h") }
                    }
                    .pickerStyle(.menu)
                    Picker("", selection: Binding(
                        get: { vm.durationMinutes },
                        set: { vm.durationMinutes = $0 }
                    )) {
                        ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)m") }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Notes", systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Optional notes...", text: Binding(
                        get: { vm.notes },
                        set: { vm.notes = $0 }
                    ), axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
                    .padding(10)
                    .background(Color.geckoBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Session Details", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding()
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Save Button

    private func saveButtonRow(_ vm: NewSessionViewModel) -> some View {
        Button { saveSession(vm) } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Save Session (\(vm.climbs.count) climbs)")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(vm.climbs.isEmpty ? Color.gray.opacity(0.2) : Color.geckoGreen)
            .foregroundColor(vm.climbs.isEmpty ? .secondary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSave(vm))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.climbing")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Select a grade and tap an outcome\nto log your first climb")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Outcome Tap Handler

    private func handleOutcomeTap(_ outcome: ClimbOutcome, vm: NewSessionViewModel) {
        if outcome == .flash {
            // Flash always logs immediately
            logClimb(vm: vm, outcome: .flash, attempts: 1)
        } else if selectedOutcome == outcome {
            // Double-tap already-selected outcome → log the climb
            logClimb(vm: vm, outcome: outcome, attempts: attempts)
        } else {
            // First tap → select the outcome
            withAnimation(.bouncy) {
                selectedOutcome = outcome
                attempts = outcome.defaultAttempts
            }
        }
    }

    // MARK: - Log Climb

    private func logClimb(vm: NewSessionViewModel, outcome: ClimbOutcome, attempts: Int) {
        withAnimation(.bouncy) {
            vm.addClimb(grade: selectedGrade, outcome: outcome, attempts: attempts)
        }
        lastLoggedClimbId = vm.climbs.first?.climbId
        withAnimation(.bouncy) {
            selectedOutcome = .sent
            self.attempts = 2
        }
    }

    // MARK: - Helpers

    private func saveSession(_ vm: NewSessionViewModel) {
        Task {
            if let session = await vm.saveSession(context: modelContext) {
                finishedSession = session
                showCelebration = true
            }
        }
    }

    private func canSave(_ vm: NewSessionViewModel) -> Bool {
        !vm.gymName.trimmingCharacters(in: .whitespaces).isEmpty && !vm.isLoading
    }
}
