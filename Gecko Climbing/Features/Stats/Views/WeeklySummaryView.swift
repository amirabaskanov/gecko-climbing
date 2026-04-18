import SwiftUI

struct WeeklySummaryView: View {
    @Environment(AppEnvironment.self) private var appEnv
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WeeklySummaryViewModel?
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        content(vm)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.geckoBackground)
            .navigationTitle("Weekly Recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.geckoBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.geckoPrimary)
                }
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            let vm = WeeklySummaryViewModel(
                sessionRepository: appEnv.sessionRepository,
                userId: authViewModel.currentUserId
            )
            viewModel = vm
            Task { await vm.load() }
        }
    }

    @ViewBuilder
    private func content(_ vm: WeeklySummaryViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection(vm)
                if vm.hasActivity {
                    statsGrid(vm)
                    if !vm.gradeBreakdown.isEmpty {
                        gradeBreakdownSection(vm)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.vertical, 16)
        }
        .onAppear {
            withAnimation(.geckoSpring.delay(0.1)) {
                appeared = true
            }
        }
    }

    private func headerSection(_ vm: WeeklySummaryViewModel) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.geckoPrimary)
                .staggeredAppear(index: 0, appeared: appeared)

            Text("Your Week in Review")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .staggeredAppear(index: 0, appeared: appeared)

            Text(vm.dateRangeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .staggeredAppear(index: 0, appeared: appeared)
        }
        .padding(.top, 8)
    }

    private func statsGrid(_ vm: WeeklySummaryViewModel) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(
                    value: "\(vm.totalSessions)",
                    label: "Sessions",
                    icon: "figure.climbing",
                    color: .geckoPrimary,
                    index: 1
                )
                statCard(
                    value: vm.highestGrade,
                    label: "Top Grade",
                    icon: "trophy.fill",
                    color: Color.gradeColor(for: vm.highestGradeNumeric),
                    index: 2
                )
            }

            HStack(spacing: 12) {
                statCard(
                    value: "\(vm.totalSends)",
                    label: "Sends",
                    icon: "checkmark.seal.fill",
                    color: .geckoSentGreen,
                    index: 3
                )
                statCard(
                    value: "\(vm.flashCount)",
                    label: "Flashes",
                    icon: "bolt.fill",
                    color: .geckoFlashGold,
                    index: 4
                )
            }

            HStack(spacing: 12) {
                statCard(
                    value: formatDuration(vm.totalDurationMinutes),
                    label: "Time Climbing",
                    icon: "clock.fill",
                    color: .geckoAttemptBlue,
                    index: 5
                )
                statCard(
                    value: "\(Int(vm.sendRate * 100))%",
                    label: "Send Rate",
                    icon: "percent",
                    color: .geckoOrange,
                    index: 6
                )
            }
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

    private func gradeBreakdownSection(_ vm: WeeklySummaryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Breakdown")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 16)
                .staggeredAppear(index: 7, appeared: appeared)

            VStack(spacing: 8) {
                let maxCount = vm.gradeBreakdown.map(\.count).max() ?? 1
                ForEach(vm.gradeBreakdown) { item in
                    HStack(spacing: 12) {
                        Text(item.grade)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(width: 32, alignment: .trailing)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gradeGradient(for: item.numeric))
                                .frame(width: max(geo.size.width * CGFloat(item.count) / CGFloat(maxCount), 24))
                        }
                        .frame(height: 24)

                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)
                    }
                }
            }
            .padding(16)
            .cardStyle()
            .padding(.horizontal, 16)
            .staggeredAppear(index: 8, appeared: appeared)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.geckoSecondaryText.opacity(0.5))

            Text("No sessions this week")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text("Get out there and climb!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .staggeredAppear(index: 1, appeared: appeared)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
    }
}
