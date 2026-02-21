import SwiftUI

struct StatsView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: StatsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Stats")
        .toolbarBackground(Color.geckoBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            if viewModel == nil {
                let vm = StatsViewModel(
                    sessionRepository: appEnv.sessionRepository,
                    userId: authViewModel.currentUserId
                )
                viewModel = vm
                Task { await vm.loadStats() }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: StatsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary cards
                summaryRow(vm)

                // Grade pyramid
                GradePyramidView(data: vm.gradePyramidData)
                    .padding(.horizontal, 16)

                // Progress chart
                ProgressChartView(data: vm.progressData)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color.geckoBackground)
        .refreshable { await vm.loadStats() }
    }

    private func summaryRow(_ vm: StatsViewModel) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(value: "\(vm.totalSessions)", label: "Sessions", icon: "figure.climbing", color: Color.geckoGreen)
            statCard(value: vm.highestGrade, label: "Top Grade", icon: "trophy.fill", color: Color.gradeColor(for: vm.highestGradeNumeric))
            statCard(value: "\(vm.totalSends)", label: "Total Sends", icon: "checkmark.seal.fill", color: Color.geckoOrange)
            statCard(value: "\(vm.currentStreak)", label: "Day Streak", icon: "flame.fill", color: .orange)
        }
        .padding(.horizontal, 16)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle()
    }
}
