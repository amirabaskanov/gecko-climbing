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
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
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
            NewSessionView { session in
                viewModel?.sessions.insert(session, at: 0)
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
                    ForEach(vm.sessions) { session in
                        Button {
                            router.push(.sessionDetail(sessionId: session.sessionId))
                        } label: {
                            SessionRowView(session: session)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { offsets in
                        for idx in offsets {
                            let session = vm.sessions[idx]
                            Task { await vm.deleteSession(session, context: modelContext) }
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.geckoBackground)
            }
        }
        .background(Color.geckoBackground)
        .refreshable { await vm.loadSessions() }
        .errorAlert(error: Binding(get: { vm.error }, set: { _ in }))
    }
}

struct SessionRowView: View {
    let session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.gymName)
                        .font(.headline)
                    Text(session.date.sessionDateFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !session.highestGrade.isEmpty {
                    GradeBadge(grade: session.highestGrade, isCompleted: true)
                }
            }

            HStack(spacing: 12) {
                if session.flashCount > 0 {
                    Label("\(session.flashCount)", systemImage: "bolt.fill")
                        .foregroundColor(Color.geckoFlashGold)
                }
                Label("\(session.completedClimbs) sends", systemImage: "checkmark.circle.fill")
                    .foregroundColor(Color.geckoGreen)
                if session.projectCount > 0 {
                    Label("\(session.projectCount)", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundColor(Color.geckoProjectBlue)
                }
                Spacer()
                Label(session.durationMinutes.durationFormatted, systemImage: "clock")
                    .foregroundColor(.secondary)
            }
            .font(.caption.weight(.medium))
        }
        .padding()
        .cardStyle()
    }
}
