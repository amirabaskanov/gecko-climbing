import SwiftUI

struct CommentsView: View {
    @State var viewModel: CommentsViewModel
    @FocusState private var isInputFocused: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Header
            HStack {
                Text("Comments")
                    .font(.headline.weight(.bold))
                    .fontDesign(.rounded)

                if viewModel.totalCount > 0 {
                    Text("\(viewModel.totalCount)")
                        .font(.caption.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.geckoPrimary, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(alignment: .trailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 16)
                }
            }

            Divider()

            // Comments list
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        if viewModel.threads.isEmpty && !viewModel.isLoading {
                            emptyState
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(viewModel.threads.enumerated()), id: \.element.id) { index, thread in
                                    // Root comment
                                    CommentRowView(
                                        comment: thread.root,
                                        onReply: { viewModel.startReply(to: thread.root) },
                                        onDelete: viewModel.isOwnComment(thread.root) ? {
                                            Task { await viewModel.deleteComment(thread.root) }
                                        } : nil
                                    )
                                    .staggeredAppear(index: index, appeared: appeared)
                                    .id(thread.root.id)

                                    // Replies
                                    ForEach(thread.replies) { reply in
                                        CommentRowView(
                                            comment: reply,
                                            isReply: true,
                                            onReply: { viewModel.startReply(to: reply) },
                                            onDelete: viewModel.isOwnComment(reply) ? {
                                                Task { await viewModel.deleteComment(reply) }
                                            } : nil
                                        )
                                        .id(reply.id)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.totalCount) { _, _ in
                        if let lastId = viewModel.comments.last?.id {
                            withAnimation(.geckoSnappy) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // @mention suggestions overlay
                if !viewModel.mentionSuggestions.isEmpty {
                    mentionSuggestionsView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            Divider()

            // Reply indicator + Input bar
            VStack(spacing: 0) {
                if let replyTarget = viewModel.replyingTo {
                    replyBanner(replyTarget)
                }
                commentInput
            }
        }
        .background(Color.surfaceBackground)
        .task {
            await viewModel.loadComments()
            withAnimation(.geckoSpring) { appeared = true }
        }
        .errorAlert(error: Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        ))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.geckoMint)

            Text("No comments yet")
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)

            Text("Be the first to comment!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Reply Banner

    private func replyBanner(_ target: CommentModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.caption2)
                .foregroundStyle(Color.geckoPrimary)

            Text("Replying to **\(target.userDisplayName)**")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation(.geckoSnappy) { viewModel.cancelReply() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.geckoPrimary.opacity(0.06))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - @Mention Suggestions

    private var mentionSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.mentionSuggestions.prefix(4)) { user in
                Button {
                    viewModel.insertMention(user)
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(url: user.profileImageURL, size: 28, name: user.displayName)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.displayName)
                                .font(.caption.weight(.semibold))
                            Text("@\(user.username)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if user.id != viewModel.mentionSuggestions.prefix(4).last?.id {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Input Bar

    private var commentInput: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(viewModel.inputPlaceholder, text: Binding(
                get: { viewModel.newCommentText },
                set: { viewModel.onTextChanged($0) }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .lineLimit(1...5)
            .focused($isInputFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            .onSubmit {
                Task { await viewModel.sendComment() }
            }

            Button {
                Task { await viewModel.sendComment() }
            } label: {
                Group {
                    if viewModel.isSending {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 34, height: 34)
                .background(
                    viewModel.canSend ? Color.geckoPrimary : Color.geckoPrimary.opacity(0.35),
                    in: Circle()
                )
            }
            .disabled(!viewModel.canSend)
            .animation(.geckoSnappy, value: viewModel.canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Comment Row

struct CommentRowView: View {
    let comment: CommentModel
    var isReply: Bool = false
    var onReply: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(
                url: comment.userProfileImageURL,
                size: isReply ? 24 : 32,
                name: comment.userDisplayName
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.userDisplayName)
                        .font(.caption.weight(.bold))
                        .fontDesign(.rounded)

                    Text(comment.createdAt.relativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                MentionText(text: comment.text, mentions: comment.mentions)

                // Reply button
                if let onReply {
                    Button {
                        onReply()
                    } label: {
                        Text("Reply")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.geckoPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            if onDelete != nil {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, isReply ? 42 : 16)
        .padding(.trailing, 16)
        .padding(.vertical, isReply ? 6 : 10)
        .confirmationDialog("Delete comment?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete?() }
        }
    }
}

// MARK: - Mention Text

/// Renders comment text with @mentions highlighted in the brand color
struct MentionText: View {
    let text: String
    let mentions: [String]

    var body: some View {
        if mentions.isEmpty {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            formattedText
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formattedText: Text {
        var result = Text("")
        var remaining = text

        while !remaining.isEmpty {
            // Find the next @mention
            var earliest: (range: Range<String.Index>, name: String)?
            for name in mentions {
                let token = "@\(name)"
                if let range = remaining.range(of: token) {
                    if earliest == nil || range.lowerBound < earliest!.range.lowerBound {
                        earliest = (range, name)
                    }
                }
            }

            if let match = earliest {
                // Text before the mention
                let before = String(remaining[remaining.startIndex..<match.range.lowerBound])
                if !before.isEmpty {
                    result = result + Text(before)
                }
                // The mention itself
                result = result + Text("@\(match.name)")
                    .fontWeight(.semibold)
                    .foregroundColor(.geckoPrimary)

                remaining = String(remaining[match.range.upperBound...])
            } else {
                result = result + Text(remaining)
                remaining = ""
            }
        }

        return result
    }
}
