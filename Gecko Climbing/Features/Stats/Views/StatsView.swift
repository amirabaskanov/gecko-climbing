import SwiftUI

struct StatsView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel: StatsViewModel?
    @State private var appeared = false

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.surfaceBackground, for: .navigationBar)
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
        .background(Color.surfaceBackground)
        .refreshable { await vm.loadStats() }
        .onAppear {
            withAnimation(.geckoSpring.delay(0.1)) {
                appeared = true
            }
        }
    }

    private func summaryRow(_ vm: StatsViewModel) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(value: "\(vm.totalSessions)", label: "Sessions", icon: "figure.climbing", color: Color.geckoPrimary, index: 0)
            statCard(value: vm.highestGrade, label: "Top Grade", icon: "trophy.fill", color: Color.gradeColor(for: vm.highestGradeNumeric), index: 1)
            statCard(value: "\(vm.totalSends)", label: "Total Sends", icon: "checkmark.seal.fill", color: Color.geckoOrange, index: 2)
            statCard(value: "\(vm.currentStreak)", label: "Day Streak", icon: "flame.fill", color: .orange, index: 3)
        }
        .padding(.horizontal, 16)
    }

    private func statCard(value: String, label: String, icon: String, color: Color, index: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.06), color.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.1), lineWidth: 1)
        )
        .cardStyle()
        .staggeredAppear(index: index, appeared: appeared)
    }
}
