import SwiftUI

struct SessionDetailView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @State private var viewModel: SessionDetailViewModel?
    let session: SessionModel

    @State private var showAddClimb = false

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
                Button {
                    showAddClimb = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color.geckoGreen)
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
    }

    @ViewBuilder
    private func content(_ vm: SessionDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statsHeader(vm)
                    .padding(.horizontal, 16)

                if vm.session.climbs.isEmpty {
                    EmptyStateView(
                        icon: "figure.climbing",
                        title: "No climbs yet",
                        subtitle: "Tap + to add a climb to this session",
                        actionLabel: "Add Climb"
                    ) { showAddClimb = true }
                    .frame(height: 200)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.sortedClimbs) { climb in
                            ClimbRowView(climb: climb)
                                .padding(.horizontal, 16)
                            Divider().padding(.leading, 16)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.geckoBackground)
    }

    private func statsHeader(_ vm: SessionDetailViewModel) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Color.geckoGreen)
                Text(session.date.sessionDateFormatted)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "clock")
                    .foregroundColor(Color.geckoOrange)
                Text(session.durationMinutes.durationFormatted)
                    .font(.subheadline)
            }
            .foregroundColor(.secondary)

            HStack(spacing: 0) {
                statCard(value: "\(vm.flashes.count + vm.sends.count)", label: "Sends")
                Divider().frame(height: 40)
                statCard(value: "\(vm.session.totalClimbs)", label: "Attempts")
                Divider().frame(height: 40)
                statCard(value: "\(vm.flashes.count)", label: "Flashes",
                         valueColor: vm.flashes.isEmpty ? .secondary : .geckoFlashGold)
                Divider().frame(height: 40)
                statCard(value: vm.session.highestGrade.isEmpty ? "—" : vm.session.highestGrade,
                         label: "Top Send",
                         valueColor: vm.session.highestGrade.isEmpty ? .secondary : Color.gradeColor(for: vm.session.highestGradeNumeric))
            }
            .cardStyle(cornerRadius: 14)

            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func statCard(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(valueColor)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
