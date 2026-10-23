import SwiftUI

/// Another climber's profile. Left-aligned identity header, inline stats,
/// one prominent follow action, then the thing only a climbing app can
/// show: their grade pyramid, in gym tape colors, followed by the sessions
/// behind it.
struct FriendProfileView: View {
    @Environment(AppEnvironment.self) private var appEnv
    let uid: String

    @State private var viewModel: FriendProfileViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.geckoBackground)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = FriendProfileViewModel(
                    uid: uid,
                    userRepository: appEnv.userRepository,
                    sessionRepository: appEnv.sessionRepository
                )
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: FriendProfileViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let user = vm.user {
                    header(user)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    statsRow(user)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    FollowButton(
                        isFollowing: vm.isFollowing,
                        style: .prominent,
                        displayName: user.displayName
                    ) {
                        Task { await vm.toggleFollow() }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                    identityCard(user, vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    factsRow(vm)
                        .padding(.top, 12)

                    sessionsSection(vm)
                        .padding(.top, 28)
                } else if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }
            }
            .padding(.bottom, 24)
        }
        .tabBarScrollInset()
        .background(Color.geckoBackground)
        .navigationTitle(vm.user.map { "@\($0.username)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert(error: Binding(get: { vm.error }, set: { vm.error = $0 }))
    }

    // MARK: - Header

    private func header(_ user: UserModel) -> some View {
        HStack(spacing: 16) {
            AvatarView(
                url: user.profileImageURL,
                size: 84,
                name: user.displayName,
                gradeNumeric: user.highestGradeNumeric
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("@\(user.username)")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.geckoSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func statsRow(_ user: UserModel) -> some View {
        HStack(spacing: 18) {
            // View-based links: this profile is pushed from the Home, Crew and
            // Profile stacks, and only Crew registers SocialRoute destinations.
            NavigationLink {
                FollowersListView(uid: user.uid, mode: .followers)
            } label: {
                stat(value: user.followersCount, label: user.followersCount == 1 ? "follower" : "followers")
            }
            .buttonStyle(.plain)

            NavigationLink {
                FollowersListView(uid: user.uid, mode: .following)
            } label: {
                stat(value: user.followingCount, label: "following")
            }
            .buttonStyle(.plain)

            stat(value: user.totalSessions, label: user.totalSessions == 1 ? "session" : "sessions")
        }
    }

    private func stat(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.geckoSecondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Identity

    private func identityCard(_ user: UserModel, vm: FriendProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                if user.highestGradeNumeric >= 0 && !user.highestGrade.isEmpty {
                    topSendBadge(user.highestGradeNumeric)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Grade pyramid")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(pyramidSubtitle(user, vm: vm))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.geckoSecondaryText)
                }
                Spacer(minLength: 0)
            }

            if !vm.pyramidBars.isEmpty {
                ClimberPyramidView(bars: vm.pyramidBars)
            } else if vm.sessionsUnavailable {
                HStack(spacing: 10) {
                    Text("Couldn't load their sessions.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.geckoSecondaryText)
                    Button("Try again") {
                        Task { await vm.loadSessions() }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.geckoPrimary)
                }
            } else if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                Text("No sessions shared yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.geckoSecondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyleElevated()
    }

    private func pyramidSubtitle(_ user: UserModel, vm: FriendProfileViewModel) -> String {
        let climbs = max(user.totalClimbs, vm.loadedClimbCount)
        let sessions = max(user.totalSessions, vm.sessions.count)
        guard climbs > 0 else { return "Nothing logged yet" }
        return "\(climbs) climb\(climbs == 1 ? "" : "s") across \(sessions) session\(sessions == 1 ? "" : "s")"
    }

    private func topSendBadge(_ numeric: Int) -> some View {
        let ink = VGrade.textColor(for: numeric)
        return VStack(spacing: 2) {
            Text(GradeDisplaySettings.shared.label(for: numeric))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
            Text("TOP SEND")
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(ink.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.gradeColor(for: numeric), in: GeckoHoldShape())
        .accessibilityLabel("Top send \(GradeDisplaySettings.shared.label(for: numeric))")
    }

    // MARK: - Facts

    @ViewBuilder
    private func factsRow(_ vm: FriendProfileViewModel) -> some View {
        let facts = facts(vm)
        if !facts.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(facts, id: \.text) { fact in
                        HStack(spacing: 5) {
                            Image(systemName: fact.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(fact.text)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(Color.geckoInputBackground))
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func facts(_ vm: FriendProfileViewModel) -> [(icon: String, text: String)] {
        var result: [(icon: String, text: String)] = []
        if let gym = vm.homeGym {
            result.append(("mappin", "Climbs at \(gym)"))
        }
        if let rate = vm.flashRatePercent {
            result.append(("bolt.fill", "\(rate)% flash rate"))
        }
        if let last = vm.lastSessionDate {
            result.append(("clock", "Last session \(last.crewRecencySentence)"))
        }
        return result
    }

    // MARK: - Sessions

    @ViewBuilder
    private func sessionsSection(_ vm: FriendProfileViewModel) -> some View {
        if !vm.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SocialSectionHeader(title: "Recent sessions")
                VStack(spacing: 10) {
                    ForEach(vm.sessions.prefix(10)) { session in
                        SessionRowView(session: session)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}
