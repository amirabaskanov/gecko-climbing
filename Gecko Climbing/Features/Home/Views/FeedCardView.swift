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

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var heartScale: CGFloat = 1.0
    @State private var currentPhotoIndex = 0
    @State private var showDoubleTapHeart = false
    @State private var captionExpanded = false
    @State private var climbsExpanded = false
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
            // Header
            headerSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, badges.isEmpty ? 12 : 8)

            // Contextual signal row — only renders when at least one
            // badge fires. Sits between the user header and photos so the
            // signal lands the moment the eye reaches the card.
            if !badges.isEmpty {
                FeedBadgeRow(badges: badges)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Photos (swipeable, double-tap to like with heart overlay)
            if !photos.isEmpty {
                photoSection
                    .overlay {
                        // Double-tap heart animation
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

            // Caption + sends + footer
            VStack(alignment: .leading, spacing: 0) {
                if !post.caption.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.caption)
                            .font(.subheadline)
                            .lineLimit(captionExpanded ? nil : 3)

                        if post.caption.count > 120 && !captionExpanded {
                            Button("Show more") {
                                withAnimation(.geckoSnappy) { captionExpanded = true }
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.geckoPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                if !post.climbSequence.isEmpty {
                    sendsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                footerSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .cardStyle()
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
                AvatarView(url: post.userProfileImageURL, size: 42, name: post.userDisplayName)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.userDisplayName)
                        .font(.subheadline.weight(.semibold))
                    if post.userId == currentUserId {
                        Text("(you)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    Text(post.gymName)
                    Text("·")
                    Text(post.createdAt.relativeFormatted)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                    Text("TOP SEND")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gradeColor(for: post.topGradeNumeric), in: GeckoHoldShape())
            }
        }
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
        // Taller 4:5-leaning frame crops portrait shots far less than the old
        // 280pt letterbox; a fixed height keeps carousel pages uniform.
        TabView(selection: $currentPhotoIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                AsyncImageView(url: url, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipped()
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }


    // MARK: - Sends Section

    /// Max pills that fit without scrolling (~8 at 42pt each + spacing in a card)


    private var sendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLIMBS THIS SESSION")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Color.geckoPrimary)

            // The session fingerprint. Tapping toggles the chip breakdown;
            // its own gesture wins over the whole-card tap.
            SessionStripView(climbs: post.climbSequence, durationMinutes: post.sessionDurationMinutes)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.geckoSpring) { climbsExpanded.toggle() }
                }

            if climbsExpanded {
                FlowLayout(spacing: 6, rowSpacing: 6) {
                    ForEach(post.groupedChips()) { group in
                        ClimbChipView(grade: group.grade, outcome: group.outcome, count: group.count)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }


    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 10) {
            // Like button
            Button {
                onLike()
                withAnimation(.geckoSpring) { heartScale = 1.3 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.geckoSpring) { heartScale = 1.0 }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .font(.system(size: 13))
                        .foregroundStyle(post.isLikedByCurrentUser ? .red : .secondary)
                        .scaleEffect(heartScale)
                    Text("\(post.likesCount)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: post.isLikedByCurrentUser)

            // Comment button
            Button {
                onComment()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("\(post.commentsCount)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Climb count
            HStack(spacing: 4) {
                Image(systemName: "figure.climbing")
                    .font(.system(size: 11))
                Text("\(post.totalClimbs) climbs")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
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
    .padding()
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
    .padding()
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
                .fill(badge.tint.opacity(0.13))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(badge.tint.opacity(0.30), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.label)
    }
}

