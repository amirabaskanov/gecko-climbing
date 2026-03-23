import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext

    var refreshToken: UUID = UUID()

    @State private var viewModel: SessionListViewModel?
    @State private var showNewSession = false
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
            .toolbarBackground(Color.surfaceBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewSession = true
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
        .sheet(isPresented: $showNewSession) {
            NewSessionView(
                climbCount: .constant(0),
                finishTrigger: UUID(),
                onSessionSaved: { session in
                    viewModel?.sessions.insert(session, at: 0)
                }
            )
        }
        .onAppear {
            if viewModel == nil {
                let vm = SessionListViewModel(
                    sessionRepository: appEnv.sessionRepository,
                    postRepository: appEnv.postRepository,
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
                .background(Color.surfaceBackground)
            } else if vm.sessions.isEmpty {
                EmptyStateView(
                    
                    title: "No sessions yet",
                    subtitle: "Tap + to log your first bouldering session",
                    actionLabel: "Start Session"
                ) { showNewSession = true }
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
                .background(Color.surfaceBackground)
                .onAppear {
                    withAnimation { appeared = true }
                }
            }
        }
        .background(Color.surfaceBackground)
        .refreshable { await vm.loadSessions() }
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 })) {
            Task { await vm.loadSessions() }
        }
    }
}

struct SessionRowView: View {
    let session: SessionModel

    /// Completed climbs in chronological order (as logged), grouped into consecutive runs
    private var gradeChips: [(grade: String, numeric: Int, count: Int)] {
        let completed = session.climbs.filter { $0.climbOutcome.isCompleted }
        var chips: [(grade: String, numeric: Int, count: Int)] = []
        for climb in completed {
            if let last = chips.last, last.numeric == climb.gradeNumeric {
                chips[chips.count - 1].count += 1
            } else {
                chips.append((grade: climb.grade, numeric: climb.gradeNumeric, count: 1))
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
                        ForEach(gradeChips, id: \.numeric) { chip in
                            gradeChip(grade: chip.grade, numeric: chip.numeric, count: chip.count)
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

    private func gradeChip(grade: String, numeric: Int, count: Int) -> some View {
        let color = Color.gradeColor(for: numeric)
        return HStack(spacing: 4) {
            Text(grade)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if count > 1 {
                Text("\u{00D7}\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color, in: Capsule())
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
