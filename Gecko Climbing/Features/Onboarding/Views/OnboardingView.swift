import SwiftUI

// MARK: - First-run onboarding
//
// Lean 4-step first-run guide shown once to brand-new climbers (gated in
// MainTabView). Teaches the two things a newcomer can't guess — V-grades and
// the flash/sent/attempt outcomes — personalizes their starting grade, and
// drops them into the Log tab. Pages advance via the button only (no swipe),
// so the grade barrel's horizontal scroll doesn't fight a pager.
//
// Replayable any time from Settings → Support → "Replay the Guide".

struct OnboardingView: View {
    /// Called on finish or skip; the caller persists the seen-flag, dismisses,
    /// and routes to the Log tab.
    var onFinish: () -> Void

    /// Same key the logger reads for its default grade, so "pick your level"
    /// personalizes the very first climb they log.
    @AppStorage("lastSelectedGrade") private var lastSelectedGrade = "V5"

    @State private var page = 0
    @State private var pickedGrade = "V3"
    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch page {
                case 0: welcomePage
                case 1: gradePage
                case 2: outcomesPage
                default: readyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(page)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            footer
        }
        .animation(.geckoSpring, value: page)
        .background(Color.geckoBackground.ignoresSafeArea())
        .onAppear {
            // Greet replaying users at their own grade instead of the fresh
            // default — the barrel should say "we know you" on a replay.
            pickedGrade = lastSelectedGrade
            AnalyticsService.capture(.onboardingStarted)
            AnalyticsService.capture(.onboardingPageViewed, properties: ["page": 0])
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Spacer()
            if page < lastPage {
                Button("Skip") { finish(skipped: true) }
                    .font(.subheadline.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.geckoSecondaryText)
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0...lastPage, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.geckoPrimary : Color.geckoDivider)
                        .frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.geckoSnappy, value: page)

            Button {
                advance()
            } label: {
                Text(page == lastPage ? "Start climbing" : "Continue")
                    .font(.body.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.geckoPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .bouncePress()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private func advance() {
        if page < lastPage {
            withAnimation(.geckoSpring) { page += 1 }
            AnalyticsService.capture(.onboardingPageViewed, properties: ["page": page])
        } else {
            finish(skipped: false)
        }
    }

    private func finish(skipped: Bool) {
        // Only persist the grade pick if the user actually reached the grade
        // page — skipping from the welcome screen must never overwrite an
        // established climber's logger default with the barrel's initial value.
        if page >= 1 {
            lastSelectedGrade = pickedGrade
        }
        AnalyticsService.capture(
            skipped ? .onboardingSkipped : .onboardingCompleted,
            properties: ["page": page]
        )
        onFinish()
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            GeckoLogoView(size: 104, color: .geckoPrimary)
            VStack(spacing: 12) {
                Text("Welcome to Gecko")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Log your climbs in seconds.\nWatch yourself get stronger.")
                    .font(.title3)
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.geckoSecondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var gradePage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 4)
            pageHeadline("What's your level?",
                         "Scroll to the grade you usually climb — we'll start you there.")
            GradeBarrelView(selectedGrade: $pickedGrade, grades: VGrade.all)
            Text("V0 is beginner and the scale climbs from there. Not sure? Pick anything — you can change it on every climb.")
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundStyle(Color.geckoSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var outcomesPage: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 4)
            pageHeadline("How'd the climb go?", "Three ways to log each climb.")
            VStack(spacing: 14) {
                outcomeRow("bolt.fill", .geckoFlashGold, "Flash", "Sent it first try")
                outcomeRow("checkmark", .geckoSentGreen, "Sent", "Sent it in 2+ tries")
                outcomeRow("arrow.counterclockwise", .geckoAttemptBlue, "Attempt", "Still working on it")
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var readyPage: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.geckoPrimary)
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.geckoPrimary.opacity(0.4), radius: 16, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            pageHeadline("Log your first climb",
                         "Tap the + in the middle of the tab bar any time to start a session. Pick a grade, tap an outcome — that's it.")
            Spacer()
            Spacer()
        }
    }

    // MARK: Bits

    private func pageHeadline(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(Color.geckoSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private func outcomeRow(_ icon: String, _ color: Color, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.geckoSecondaryText)
            }
            Spacer()
        }
        .padding(14)
        .cardStyle()
    }
}

extension Notification.Name {
    /// Posted by Settings → "Replay the Guide"; MainTabView re-presents the
    /// onboarding cover, bypassing the once-per-user gate.
    static let replayOnboarding = Notification.Name("replayOnboarding")
}

#if DEBUG
#Preview("Onboarding") {
    OnboardingView(onFinish: {})
}
#endif
