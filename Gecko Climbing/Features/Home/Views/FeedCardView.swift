import SwiftUI

struct FeedCardView: View {
    let post: PostModel
    var currentUserId: String = ""
    /// Contextual badges for this post relative to the local viewer (your gym,
    /// your level, author's PR). Empty for posts that don't qualify; the
    /// badge row is hidden in that case so cards without context stay clean.
    var badges: [FeedBadge] = []
    let onLike: () -> Void
    let onComment: () -> Void
    let onUserTap: () -> Void
    var onCardTap: (() -> Void)?
    /// Submit a report for this post with the given reason. When nil, the
    /// "..." moderation menu is hidden — useful for previews and embedded
    /// contexts where moderation lives at a higher level.
    var onReport: ((ReportModel.Reason) -> Void)?
    /// Block the post's author. Nil hides the block action.
    var onBlock: (() -> Void)?
    /// Post detail shows every climb up front instead of the two-row cap.
    var showsAllClimbs: Bool = false

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var heartScale: CGFloat = 1.0
    @State private var currentPhotoIndex = 0
    @State private var showDoubleTapHeart = false
    @State private var captionExpanded = false
    @State private var showReportDialog = false
    @State private var showBlockDialog = false
    @State private var reportSubmitted = false
    @State private var didBlock = false

    private var canModerate: Bool {
        post.userId != currentUserId && (onReport != nil || onBlock != nil)
    }

    private var photos: [String] {
        if !post.imageURLs.isEmpty { return post.imageURLs }
        if let url = post.imageURL, !url.isEmpty { return [url] }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            // Contextual signal row, only when at least one badge fires.
            if !badges.isEmpty {
                FeedBadgeRow(badges: badges)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Photos run edge to edge, like every modern feed.
            if !photos.isEmpty {
                photoSection
                    .overlay {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 8)
                            .scaleEffect(showDoubleTapHeart ? 1.0 : 0.3)
                            .opacity(showDoubleTapHeart ? 1 : 0)
                    }
                    .onTapGesture(count: 2) { doubleTapLike() }
                    .padding(.bottom, 12)
            }

            if !post.caption.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.caption)
                        .font(.system(size: 15))
                        .lineLimit(captionExpanded ? nil : 3)

                    if post.caption.count > 120 && !captionExpanded {
                        Button("more") {
                            withAnimation(.geckoSnappy) { captionExpanded = true }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.geckoSecondaryText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            if !post.climbSequence.isEmpty {
                sessionSummary
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }

            footerSection
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            Divider().overlay(Color.geckoDivider)
        }
        .background(Color.geckoBackground)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { doubleTapLike() }
        .onTapGesture(count: 1) { onCardTap?() }
    }

    private func doubleTapLike() {
        guard !post.isLikedByCurrentUser else { return }
        onLike()
        withAnimation(.geckoSpring) {
            heartScale = 1.3
            showDoubleTapHeart = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.geckoSpring) { heartScale = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) { showDoubleTapHeart = false }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Button(action: onUserTap) {
                AvatarView(
                    url: post.userProfileImageURL,
                    size: 44,
                    name: post.userDisplayName,
                    gradeNumeric: post.topGradeNumeric
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(post.userDisplayName)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.userDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    if post.userId == currentUserId {
                        Text("you")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.geckoSecondaryText)
                    }
                }
                Text(headerMeta)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.geckoSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if canModerate {
                moderationMenu
            }

            // Top send badge — the signature hold shape in the climb's own
            // grade-bucket color, so the badge itself tells you how hard the
            // send was before you read the number.
            if !post.topGrade.isEmpty {
                let textColor = VGrade.textColor(for: post.topGradeNumeric)
                VStack(spacing: 2) {
                    Text(GradeDisplaySettings.shared.label(for: post.topGradeNumeric))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                    Text("TOP SEND")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.gradeColor(for: post.topGradeNumeric), in: GeckoHoldShape())
                .accessibilityLabel("Top send \(GradeDisplaySettings.shared.label(for: post.topGradeNumeric))")
            }
        }
    }

    private var headerMeta: String {
        let gym = post.gymName.trimmedGymName
        let when = post.createdAt.relativeFormatted
        return gym.isEmpty ? when : "\(gym) · \(when)"
    }

    // MARK: - Moderation menu (Apple Guideline 1.2)

    private var moderationMenu: some View {
        Menu {
            if onReport != nil {
                Button {
                    showReportDialog = true
                } label: {
                    Label("Report post", systemImage: "flag")
                }
            }
            if onBlock != nil {
                Button(role: .destructive) {
                    showBlockDialog = true
                } label: {
                    Label("Block \(post.userDisplayName)", systemImage: "hand.raised")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.geckoSecondaryText)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("More options")
        .confirmationDialog(
            "Report this post",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            ForEach(ReportModel.Reason.allCases) { reason in
                Button(reason.rawValue) {
                    onReport?(reason)
                    reportSubmitted.toggle()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Tell us what's going on. Our team will review this.")
        }
        .confirmationDialog(
            "Block \(post.userDisplayName)?",
            isPresented: $showBlockDialog,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                onBlock?()
                didBlock.toggle()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You won't see their posts. They won't see yours. You can unblock anyone later in Settings.")
        }
        .sensoryFeedback(.success, trigger: reportSubmitted)
        .sensoryFeedback(.impact(weight: .medium), trigger: didBlock)
    }

    // MARK: - Photos

    private var photoSection: some View {
        // Edge to edge, 4:5-leaning. A fixed height keeps carousel pages
        // uniform; the card's own padding never touches the photo.
        TabView(selection: $currentPhotoIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                AsyncImageView(url: url, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
        .frame(height: 400)
        .clipped()
    }

    // MARK: - Session summary

    /// The session at a glance: three headline numbers, then the climbs
    /// themselves as grouped hold chips. No label above it; the chips are
    /// self-explanatory and the numbers do the talking.
    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            statsRow
            SessionChipsView(
                climbs: post.climbSequence,
                groups: post.groupedChips(),
                durationMinutes: post.sessionDurationMinutes,
                showsStats: false,
                startsExpanded: showsAllClimbs
            )
        }
    }

    private var statsRow: some View {
        let tally = post.outcomeTally
        let count = post.climbSequence.count
        return HStack(alignment: .firstTextBaseline, spacing: 24) {
            headlineStat(value: "\(count)", label: count == 1 ? "climb" : "climbs")
            if tally.flashes > 0 {
                headlineStat(value: "\(tally.flashes)", label: tally.flashes == 1 ? "flash" : "flashes", icon: "bolt.fill", tint: .geckoFlashGoldDeep)
            } else if tally.sends > 0 {
                headlineStat(value: "\(tally.sends)", label: tally.sends == 1 ? "send" : "sends")
            }
            if let minutes = post.sessionDurationMinutes, minutes > 0 {
                headlineStat(value: SessionChipsView.formatDuration(minutes), label: "on the wall")
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func headlineStat(value: String, label: String, icon: String? = nil, tint: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.geckoSecondaryText)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 22) {
            Button {
                onLike()
                withAnimation(.geckoSpring) { heartScale = 1.3 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.geckoSpring) { heartScale = 1.0 }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(post.isLikedByCurrentUser ? Color.red : Color.primary)
                        .scaleEffect(heartScale)
                        .contentTransition(.symbolEffect(.replace))
                    if post.likesCount > 0 {
                        Text("\(post.likesCount)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: post.isLikedByCurrentUser)
            .accessibilityLabel(post.isLikedByCurrentUser ? "Unlike, \(post.likesCount) likes" : "Like, \(post.likesCount) likes")

            Button {
                onComment()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.primary)
                    if post.commentsCount > 0 {
                        Text("\(post.commentsCount)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comments, \(post.commentsCount)")

            Spacer()
        }
    }
}

// MARK: - Hatching Texture

#if DEBUG
#Preview("Feed card — light") {
    FeedCardView(
        post: .preview,
        currentUserId: "preview_user",
        badges: [
            .personalBest(grade: "V5"),
            .yourGym(name: "Movement Denver")
        ],
        onLike: {},
        onComment: {},
        onUserTap: {}
    )
    .background(Color.geckoBackground)
    .preferredColorScheme(.light)
}

#Preview("Feed card — dark") {
    FeedCardView(
        post: .preview,
        currentUserId: "preview_user",
        badges: [.yourLevel(grade: "V5")],
        onLike: {},
        onComment: {},
        onUserTap: {}
    )
    .background(Color.geckoBackground)
    .preferredColorScheme(.dark)
}
#endif

// MARK: - FeedBadgeRow

/// Compact horizontal chip row shown between a feed card's header and its
/// content. Each chip is a contextual reason the post matters to the viewer
/// (e.g. "Your gym", "V5 personal best"). At most ~3 chips per card so the
/// row stays single-line on standard widths; longer rows scroll horizontally.
struct FeedBadgeRow: View {
    let badges: [FeedBadge]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(badges, id: \.self) { badge in
                    FeedBadgeChip(badge: badge)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

/// Pill-shaped contextual badge. Tinted by the badge's `tint` color with a
/// soft fill + matching outline + bold text — distinct enough to read at a
/// glance, restrained enough to not fight the post content.
struct FeedBadgeChip: View {
    let badge: FeedBadge

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: badge.icon)
                .font(.system(size: 10, weight: .heavy))
            Text(badge.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(badge.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(badge.tint.opacity(0.14))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.label)
    }
}

