import SwiftUI

struct CelebrationView: View {
    let session: SessionModel
    let onDone: (PostModel?) -> Void

    @State private var caption = ""
    @State private var showShareComposer = false
    @State private var animateIn = false

    var body: some View {
        if showShareComposer {
            shareComposer
        } else {
            celebrationScreen
        }
    }

    private var celebrationScreen: some View {
        ZStack {
            Color.geckoGreen.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                    .scaleEffect(animateIn ? 1.0 : 0.3)
                    .animation(.bouncy(duration: 0.5).delay(0.1), value: animateIn)

                VStack(spacing: 8) {
                    Text("Session Complete!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(session.gymName)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut.delay(0.2), value: animateIn)

                // Stats cards
                HStack(spacing: 12) {
                    if session.flashCount > 0 {
                        miniStat(value: "\(session.flashCount)", label: "Flashes")
                    }
                    miniStat(value: "\(session.completedClimbs)", label: "Sends")
                    miniStat(value: "\(session.totalClimbs)", label: "Climbs")
                    miniStat(value: session.durationMinutes.durationFormatted, label: "Duration")
                    if !session.highestGrade.isEmpty {
                        miniStat(value: session.highestGrade, label: "Top Send")
                    }
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .animation(.easeOut.delay(0.3), value: animateIn)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        withAnimation { showShareComposer = true }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share to Feed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(Color.geckoGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        onDone(nil)
                    } label: {
                        Text("Save Privately")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear { animateIn = true }
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var shareComposer: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session summary
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.gymName)
                                .font(.headline)
                            Text("\(session.completedClimbs) sends · \(session.durationMinutes.durationFormatted)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !session.highestGrade.isEmpty {
                            GradeBadge(grade: session.highestGrade, isCompleted: true, size: .large)
                        }
                    }
                    .padding()
                    .cardStyle()

                    // Caption
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Caption")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        TextField("Write something about this session...", text: $caption, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .padding()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 4)
                    }

                    Button {
                        let gradeCounts = Dictionary(
                            grouping: session.climbs.filter { $0.climbOutcome.isCompleted },
                            by: { $0.grade }
                        ).mapValues { $0.count }

                        let post = PostModel(
                            userId: session.userId,
                            sessionId: session.sessionId,
                            gymName: session.gymName,
                            caption: caption,
                            topGrade: session.highestGrade,
                            topGradeNumeric: session.highestGradeNumeric,
                            totalClimbs: session.totalClimbs,
                            gradeCounts: gradeCounts
                        )
                        onDone(post)
                    } label: {
                        Text("Share Session")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.geckoGreen)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .background(Color.geckoBackground)
            .navigationTitle("Share to Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onDone(nil) }
                }
            }
        }
    }
}
