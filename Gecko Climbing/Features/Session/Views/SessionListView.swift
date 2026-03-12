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
                            .foregroundColor(Color.geckoGreen)
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
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.sessions.isEmpty {
                EmptyStateView(
                    icon: "figure.climbing",
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
                .background(Color.surfaceBackground)
                .onAppear {
                    withAnimation { appeared = true }
                }
            }
        }
        .background(Color.surfaceBackground)
        .refreshable { await vm.loadSessions() }
        .errorAlert(error: Binding(get: { vm.error }, set: { _ in }))
    }
}

struct SessionRowView: View {
    let session: SessionModel

    private var gradeColor: Color {
        session.highestGrade.isEmpty ? .secondary : Color.gradeColor(for: session.highestGradeNumeric)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent stripe
            RoundedRectangle(cornerRadius: 2)
                .fill(gradeColor)
                .frame(width: 4)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.gymName)
                            .font(.headline)
                        Text(session.date.sessionDateFormatted)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !session.highestGrade.isEmpty {
                        GradeBadge(grade: session.highestGrade, isCompleted: true)
                    }
                }

                HStack(spacing: 8) {
                    if session.flashCount > 0 {
                        statPill(icon: "bolt.fill", text: "\(session.flashCount)", color: .geckoFlashGold)
                    }
                    statPill(icon: "checkmark.circle.fill", text: "\(session.completedClimbs) sends", color: .geckoGreen)
                    if session.attemptCount > 0 {
                        statPill(icon: "arrow.trianglehead.counterclockwise", text: "\(session.attemptCount)", color: .geckoAttemptBlue)
                    }
                    Spacer()
                    statPill(icon: "clock", text: session.durationMinutes.durationFormatted, color: .secondary)
                }
            }
            .padding()
        }
        .cardStyle()
    }

    private func statPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
