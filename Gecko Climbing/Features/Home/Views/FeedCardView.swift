import SwiftUI

struct FeedCardView: View {
    let post: PostModel
    var currentUserId: String = ""
    let onLike: () -> Void
    let onComment: () -> Void
    let onUserTap: () -> Void
    var onCardTap: (() -> Void)?

    @State private var heartScale: CGFloat = 1.0
    @State private var currentPhotoIndex = 0
    @State private var showDoubleTapHeart = false
    @State private var captionExpanded = false

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
                .padding(.bottom, 12)

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

                if !post.gradeCounts.isEmpty {
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

            // Top send badge
            if !post.topGrade.isEmpty {
                VStack(spacing: 2) {
                    Text(post.topGrade)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("TOP SEND")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gradeColor(for: post.topGradeNumeric), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Photos

    private var photoSection: some View {
        TabView(selection: $currentPhotoIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipped()
                    case .failure:
                        photoPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .background(Color.geckoInputBackground)
                    @unknown default:
                        photoPlaceholder
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color.geckoInputBackground)
            .frame(height: 280)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(.secondary)
                        .font(.title)
                    Text("Photo unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            )
    }

    // MARK: - Sends Section

    /// Max pills that fit without scrolling (~8 at 42pt each + spacing in a card)
    private let maxUnbundledPills = 8

    /// Paired (grade, outcome) sequence. Falls back to gradeCounts for very old posts
    /// that predate gradeSequence, where outcomes are assumed to all be sends.
    private var climbSequence: [(grade: String, outcome: ClimbOutcome)] {
        if !post.gradeSequence.isEmpty {
            return post.gradeSequence.enumerated().map { idx, grade in
                let raw = idx < post.outcomeSequence.count ? post.outcomeSequence[idx] : ClimbOutcome.sent.rawValue
                return (grade: grade, outcome: ClimbOutcome.fromString(raw))
            }
        }
        // Oldest posts: no sequence info at all. Use gradeCounts (all treated as sent).
        return post.gradeCounts
            .sorted { VGrade.numeric(for: $0.key) < VGrade.numeric(for: $1.key) }
            .flatMap { Array(repeating: (grade: $0.key, outcome: ClimbOutcome.sent), count: $0.value) }
    }

    /// Groups consecutive identical (grade, outcome) pairs only when the session is too long to show unbundled.
    /// A send and an attempt at the same grade stay in separate chips so the texture reads correctly.
    private var gradeChips: [(grade: String, outcome: ClimbOutcome, count: Int, index: Int)] {
        let sequence = climbSequence

        if sequence.count <= maxUnbundledPills {
            return sequence.enumerated().map { (grade: $1.grade, outcome: $1.outcome, count: 1, index: $0) }
        }

        var chips: [(grade: String, outcome: ClimbOutcome, count: Int, index: Int)] = []
        for item in sequence {
            if let last = chips.last, last.grade == item.grade, last.outcome == item.outcome {
                chips[chips.count - 1].count += 1
            } else {
                chips.append((grade: item.grade, outcome: item.outcome, count: 1, index: chips.count))
            }
        }
        return chips
    }

    private var sendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CLIMBS THIS SESSION")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(gradeChips, id: \.index) { chip in
                        gradePill(grade: chip.grade, outcome: chip.outcome, count: chip.count)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func gradePill(grade: String, outcome: ClimbOutcome, count: Int) -> some View {
        let numeric = VGrade.numeric(for: grade)
        let color = Color.gradeColor(for: numeric)
        let pillHeight: CGFloat = 32 + CGFloat(min(numeric, 10)) * 2.4
        let isAttempt = outcome == .attempt

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(isAttempt ? 0.18 : 0.85))

                if isAttempt {
                    DiagonalStripes(spacing: 5, lineWidth: 2)
                        .stroke(color.opacity(0.85), lineWidth: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(width: 36, height: pillHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(isAttempt ? 0.85 : 0), lineWidth: 1.2)
            )

            HStack(spacing: 2) {
                Text(grade)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                if count > 1 {
                    Text("×\(count)")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(color.opacity(0.6))
                }
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
                Image(systemName: "clock")
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
        onLike: {},
        onComment: {},
        onUserTap: {}
    )
    .padding()
    .background(Color.geckoBackground)
    .preferredColorScheme(.dark)
}
#endif

/// Diagonal-stripe pattern used to mark attempts vs completed sends.
struct DiagonalStripes: Shape {
    var spacing: CGFloat = 6
    var lineWidth: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        // Sweep from just above the top-left corner to beyond the right edge so
        // stripes at both extremes fully cover the shape.
        var x: CGFloat = -h
        while x < rect.width + h {
            path.move(to: CGPoint(x: x, y: h))
            path.addLine(to: CGPoint(x: x + h, y: 0))
            x += spacing
        }
        return path
    }
}
