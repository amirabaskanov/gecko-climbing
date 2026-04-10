import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext

    var refreshToken: UUID = UUID()
    /// Switches the parent MainTabView to the Log tab. We route the "+" and
    /// "Start Session" affordances through here instead of presenting a second
    /// NewSessionView in a sheet — two live NewSessionViewModels would race on
    /// the persisted draft and the empty-instance would clobber the in-progress
    /// one when the app backgrounds.
    var onStartSession: (() -> Void)? = nil

    @State private var viewModel: SessionListViewModel?
    @State private var router = TabRouter<SessionRoute>()
    @State private var error: Error?
    @State private var appeared = false

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                if let vm = viewModel {
                    content(vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("My Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onStartSession?()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.geckoPrimary)
                            .font(.title3)
                    }
                }
            }
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .sessionDetail(let sessionId):
                    if let session = viewModel?.sessions.first(where: { $0.sessionId == sessionId }) {
                        SessionDetailView(session: session)
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = SessionListViewModel(
                    sessionRepository: appEnv.sessionRepository,
                    userId: authViewModel.currentUserId
                )
                viewModel = vm
                Task { await vm.loadSessions() }
            }
        }
        .onChange(of: refreshToken) {
            Task { await viewModel?.loadSessions() }
        }
    }

    @ViewBuilder
    private func content(_ vm: SessionListViewModel) -> some View {
        Group {
            if vm.isLoading && vm.sessions.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            SessionRowSkeleton()
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color.geckoBackground)
            } else if vm.sessions.isEmpty {
                EmptyStateView(

                    title: "No sessions yet",
                    subtitle: "Tap + to log your first bouldering session",
                    actionLabel: "Start Session"
                ) { onStartSession?() }
            } else {
                List {
                    ForEach(Array(vm.sessions.enumerated()), id: \.element.id) { index, session in
                        Button {
                            router.push(.sessionDetail(sessionId: session.sessionId))
                        } label: {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .staggeredAppear(index: index, appeared: appeared)
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            let session = vm.sessions[idx]
                            Task { await vm.deleteSession(session, context: modelContext) }
                        }
                    }
                }
                .listStyle(.plain)
                .contentMargins(.bottom, 48)
                .background(Color.geckoBackground)
                .onAppear {
                    withAnimation { appeared = true }
                }
            }
        }
        .background(Color.geckoBackground)
        .refreshable { await vm.loadSessions() }
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 })) {
            Task { await vm.loadSessions() }
        }
    }
}

struct SessionRowView: View {
    let session: SessionModel

    /// All climbs (including attempts) in chronological order, grouped into consecutive
    /// (grade, outcome) runs so a send and an attempt at the same grade stay in separate chips.
    private var gradeChips: [(grade: String, numeric: Int, outcome: ClimbOutcome, count: Int, index: Int)] {
        let ordered = session.climbs.sorted { $0.loggedAt < $1.loggedAt }
        var chips: [(grade: String, numeric: Int, outcome: ClimbOutcome, count: Int, index: Int)] = []
        for climb in ordered {
            let outcome = climb.climbOutcome
            if let last = chips.last, last.numeric == climb.gradeNumeric, last.outcome == outcome {
                chips[chips.count - 1].count += 1
            } else {
                chips.append((
                    grade: climb.grade,
                    numeric: climb.gradeNumeric,
                    outcome: outcome,
                    count: 1,
                    index: chips.count
                ))
            }
        }
        return chips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: gym + date + top grade badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.gymName)
                        .font(.subheadline.weight(.bold))

                    Text(session.date.sessionDateFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !session.highestGrade.isEmpty {
                    GradeBadge(grade: session.highestGrade, isCompleted: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Grade chips — shows what you climbed
            if !gradeChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(gradeChips, id: \.index) { chip in
                            gradeChip(
                                grade: chip.grade,
                                numeric: chip.numeric,
                                outcome: chip.outcome,
                                count: chip.count
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }

            // Footer: outcome counts + duration
            HStack(spacing: 0) {
                if session.flashCount > 0 {
                    miniStat(icon: "bolt.fill", value: "\(session.flashCount)", color: .geckoFlashGold)
                }

                miniStat(
                    icon: "checkmark.circle.fill",
                    value: "\(session.completedClimbs) send\(session.completedClimbs == 1 ? "" : "s")",
                    color: .geckoSentGreen
                )

                if session.attemptCount > 0 {
                    miniStat(icon: "arrow.trianglehead.counterclockwise", value: "\(session.attemptCount)", color: .geckoAttemptBlue)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(session.durationMinutes.durationFormatted)
                        .font(.caption2.weight(.medium))
                        .fontDesign(.rounded)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .cardStyle()
    }

    // MARK: - Grade Chip

    @ViewBuilder
    private func gradeChip(grade: String, numeric: Int, outcome: ClimbOutcome, count: Int) -> some View {
        let color = Color.gradeColor(for: numeric)
        let isAttempt = outcome == .attempt

        HStack(spacing: 4) {
            Text(grade)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isAttempt ? color : .white)

            if count > 1 {
                Text("\u{00D7}\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle((isAttempt ? color : .white).opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            ZStack {
                Capsule().fill(isAttempt ? color.opacity(0.15) : color)
                if isAttempt {
                    DiagonalStripes(spacing: 4, lineWidth: 1.5)
                        .stroke(color.opacity(0.85), lineWidth: 1.5)
                        .clipShape(Capsule())
                }
            }
        }
        .overlay(
            Capsule().stroke(color.opacity(isAttempt ? 0.85 : 0), lineWidth: 1)
        )
    }

    // MARK: - Mini Stat

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(value)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.trailing, 10)
    }
}
