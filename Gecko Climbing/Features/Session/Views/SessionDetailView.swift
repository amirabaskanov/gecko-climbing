import SwiftUI

struct SessionDetailView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SessionDetailViewModel?
    let session: SessionModel

    @State private var showAddClimb = false
    @State private var showEditSession = false
    @State private var climbToEdit: ClimbModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SessionDetailViewModel(
                    session: session,
                    sessionRepository: appEnv.sessionRepository
                )
            }
        }
        .navigationTitle(session.gymName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddClimb = true
                    } label: {
                        Label("Add Climb", systemImage: "plus.circle")
                    }
                    Button {
                        showEditSession = true
                    } label: {
                        Label("Edit Session", systemImage: "pencil")
                    }
                    Button {
                        shareSession()
                    } label: {
                        Label("Share Session", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(Color.geckoPrimary)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddClimb) {
            if let vm = viewModel {
                QuickAddClimbSheet { grade, outcome, attempts in
                    Task { await vm.addClimb(grade: grade, outcome: outcome, attempts: attempts) }
                }
            }
        }
        .sheet(item: $climbToEdit) { climb in
            if let vm = viewModel {
                EditClimbSheet(climb: climb) { grade, outcome, attempts in
                    Task { await vm.updateClimb(climb, grade: grade, outcome: outcome, attempts: attempts) }
                }
            }
        }
        .sheet(isPresented: $showEditSession) {
            if let vm = viewModel {
                EditSessionSheet(
                    gymName: vm.session.gymName,
                    notes: vm.session.notes,
                    date: vm.session.date,
                    onSave: { gymName, notes, date in
                        Task { await vm.updateSessionDetails(gymName: gymName, notes: notes, date: date) }
                    },
                    onDelete: {
                        Task {
                            await vm.deleteSession(context: modelContext)
                            dismiss()
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: SessionDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statsHeader(vm)
                    .padding(.horizontal, 16)

                if vm.session.climbs.isEmpty {
                    EmptyStateView(
                        
                        title: "No climbs yet",
                        subtitle: "Tap the menu to add a climb",
                        actionLabel: "Add Climb"
                    ) { showAddClimb = true }
                    .frame(height: 200)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.sortedClimbs) { climb in
                            ClimbRowView(climb: climb)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    climbToEdit = climb
                                }
                                .contextMenu {
                                    Button {
                                        climbToEdit = climb
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        Task { await vm.deleteClimb(climb) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await vm.deleteClimb(climb) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.geckoBackground)
        .errorAlert(error: Binding(
            get: { vm.error },
            set: { _ in vm.error = nil }
        ))
    }

    private func statsHeader(_ vm: SessionDetailViewModel) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.geckoPrimary)
                Text(session.date.sessionDateFormatted)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "clock")
                    .foregroundStyle(Color.geckoOrange)
                Text(session.durationMinutes.durationFormatted)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                statCard(value: "\(vm.session.totalClimbs)", label: "Climbs")
                Divider().frame(height: 32).opacity(0.3)
                statCard(value: "\(vm.flashes.count)", label: "Flashes",
                         valueColor: vm.flashes.isEmpty ? .secondary : .geckoFlashGold)
                Divider().frame(height: 32).opacity(0.3)
                statCard(value: "\(vm.flashes.count + vm.sends.count)", label: "Sends")
                Divider().frame(height: 32).opacity(0.3)
                statCard(value: vm.session.highestGrade.isEmpty ? "—" : vm.session.highestGrade,
                         label: "Top Send",
                         valueColor: vm.session.highestGrade.isEmpty ? .secondary : Color.gradeColor(for: vm.session.highestGradeNumeric))
            }
            .cardStyle(cornerRadius: 14)

            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func shareSession() {
        let card = SessionShareCard(
            gymName: session.gymName,
            date: session.date,
            topGrade: session.highestGrade,
            topGradeNumeric: session.highestGradeNumeric,
            totalClimbs: session.totalClimbs,
            completedClimbs: session.completedClimbs,
            flashCount: session.flashCount,
            durationMinutes: session.durationMinutes
        )
        SessionShareHelper.share(card: card)
    }

    private func statCard(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit Climb Sheet

struct EditClimbSheet: View {
    @Environment(\.dismiss) private var dismiss

    let climb: ClimbModel
    let onSave: (String, ClimbOutcome, Int) -> Void

    @State private var selectedGrade: String
    @State private var selectedOutcome: ClimbOutcome
    @State private var attempts: Int
    @State private var showAttemptSelector = false

    init(climb: ClimbModel, onSave: @escaping (String, ClimbOutcome, Int) -> Void) {
        self.climb = climb
        self.onSave = onSave
        _selectedGrade = State(initialValue: climb.grade)
        _selectedOutcome = State(initialValue: climb.climbOutcome)
        _attempts = State(initialValue: climb.attempts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Grade barrel
                    GradeBarrelView(selectedGrade: $selectedGrade)

                    // Outcome buttons (matching NewSessionView style)
                    HStack(spacing: 10) {
                        editOutcomeButton(.flash, icon: "bolt.fill", label: "FLASH")
                        editOutcomeButton(.sent, icon: "checkmark", label: "SENT")
                        editOutcomeButton(.attempt, icon: "arrow.trianglehead.counterclockwise", label: "ATTEMPT")
                    }
                    .padding(.horizontal, 16)

                    // Attempt selector
                    if selectedOutcome != .flash {
                        AttemptBubbleSelector(
                            accentColor: selectedOutcome.color,
                            minimumAttempts: selectedOutcome == .attempt ? 1 : 2
                        ) { count in
                            attempts = count
                        }
                        .padding(.horizontal, 16)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Save button
                    Button {
                        onSave(selectedGrade, selectedOutcome, attempts)
                        dismiss()
                    } label: {
                        Text("Save Changes")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.geckoPrimary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.top, 4)
            }
            .background(Color.geckoBackground)
            .navigationTitle("Edit Climb")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.geckoSnappy, value: selectedOutcome)
        }
    }

    private func editOutcomeButton(_ outcome: ClimbOutcome, icon: String, label: String) -> some View {
        Button {
            withAnimation(.geckoSnappy) {
                selectedOutcome = outcome
                if outcome == .flash { attempts = 1 }
                else { attempts = max(attempts, outcome.defaultAttempts) }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .foregroundStyle(selectedOutcome == outcome ? .white : outcome.color)
            .background(selectedOutcome == outcome ? outcome.color : outcome.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(outcome.color.opacity(selectedOutcome == outcome ? 0 : 0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .bouncePress()
        .sensoryFeedback(.selection, trigger: selectedOutcome)
    }
}

// MARK: - Edit Session Sheet

struct EditSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var gymFieldFocused: Bool

    @State private var gymName: String
    @State private var notes: String
    @State private var date: Date
    @State private var showDatePicker = false
    @State private var showDeleteConfirmation = false
    let onSave: (String, String, Date) -> Void
    var onDelete: (() -> Void)?

    init(gymName: String, notes: String, date: Date, onSave: @escaping (String, String, Date) -> Void, onDelete: (() -> Void)? = nil) {
        _gymName = State(initialValue: gymName)
        _notes = State(initialValue: notes)
        _date = State(initialValue: date)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var canSave: Bool {
        !gymName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Gym name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gym Name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.geckoPrimary)
                                .font(.system(size: 20))
                            TextField("Where did you climb?", text: $gymName)
                                .font(.body.weight(.medium))
                                .focused($gymFieldFocused)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.geckoInputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(gymFieldFocused ? Color.geckoPrimary : Color.secondary.opacity(0.15), lineWidth: gymFieldFocused ? 2 : 1)
                        )
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DatePicker("Session Date", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.geckoInputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("How was the session?", text: $notes, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .padding(16)
                            .background(Color.geckoInputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                    }
                    // Delete button
                    if onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Session")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color.geckoBackground)
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(gymName, notes, date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .alert("Delete Session?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This session and all its climbs will be permanently deleted.")
            }
        }
    }
}
