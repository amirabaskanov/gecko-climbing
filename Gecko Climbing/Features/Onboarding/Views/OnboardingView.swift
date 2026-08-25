import SwiftUI

// MARK: - First-run onboarding
//
// Lean 4-step first-run guide shown once to brand-new climbers (gated in
// MainTabView). Teaches the two things a newcomer can't guess (V-grades and
// the flash/sent/attempt outcomes), personalizes their starting grade, and
// drops them into the Log tab. The outcomes page is a hands-on lesson: the
// user logs three scripted climbs with the real outcome buttons, so the
// vocabulary is learned by doing, not reading. Pages advance via the button
// only (no swipe), so the grade barrel's horizontal scroll doesn't fight a
// pager. Continue is gated on the lesson so nobody scrolls past the one
// concept the whole app hinges on (Skip remains the escape hatch).
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
    @State private var lessonDone = false
    private let lastPage = 3

    /// Continue is locked on the outcomes page until all three practice
    /// climbs are logged. The lesson takes ~10 seconds and Skip stays live.
    private var continueLocked: Bool { page == 2 && !lessonDone }

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
                    .foregroundStyle(Color.geckoOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.geckoPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .bouncePress()
            .disabled(continueLocked)
            .opacity(continueLocked ? 0.35 : 1)
            .animation(.geckoSnappy, value: continueLocked)
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
                         "Scroll to the grade you usually climb. We'll start you there.")
            GradeBarrelView(selectedGrade: $pickedGrade, grades: VGrade.all)
            Text("V0 is beginner and the scale climbs from there. Not sure? Pick anything. You can change it on every climb.")
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundStyle(Color.geckoSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var outcomesPage: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            pageHeadline("How'd the climb go?", "Log these three climbs to see how it works.")
            OutcomeLessonView(baseGrade: pickedGrade) {
                withAnimation(.geckoSpring) { lessonDone = true }
            }
            Spacer(minLength: 0)
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
                         "Tap the + in the middle of the tab bar any time to start a session. Pick a grade, tap an outcome, and you're done.")
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

}

// MARK: - Outcome lesson
//
// The interactive heart of the guide: three scripted climbs, logged with the
// SAME outcome buttons and tries-selector the real logger uses. Flash the
// first climb, send the second and pick tries, log an attempt on the third.
// The scripted button pulses, the others wait dimmed, a used button slides
// away, and every logged climb drops into a chip tray. Finishing fires
// confetti and unlocks Continue.
private struct OutcomeLessonView: View {
    let baseGrade: String
    var onComplete: () -> Void

    private struct LessonClimb {
        let grade: String
        let outcome: ClimbOutcome
        let coach: String
    }

    private struct LoggedClimb: Identifiable {
        let id: Int
        let grade: String
        let outcome: ClimbOutcome
        let tries: Int
    }

    /// Scripted around the grade picked on the previous page (one under it,
    /// at it, one over it) so the three tray chips land in three different
    /// tape colors.
    private var climbs: [LessonClimb] {
        let base = VGrade.numeric(for: baseGrade)
        return [
            LessonClimb(grade: "V\(max(base - 1, 0))", outcome: .flash,
                        coach: "You got this one on your first try. That's a **flash**. Tap FLASH to log it."),
            LessonClimb(grade: "V\(min(base, 17))", outcome: .sent,
                        coach: "This one took you a few tries. That's a **send**. Tap SENT and pick how many."),
            LessonClimb(grade: "V\(min(base + 1, 17))", outcome: .attempt,
                        coach: "You couldn't finish this one yet. That's an **attempt**. Tap ATTEMPT, it still counts.")
        ]
    }

    private static let doneCoach = "That's all there is to it. Pick a grade, tap a button, done."

    @State private var step = 0
    @State private var logged: [LoggedClimb] = []
    @State private var showSelector = false
    @State private var flashBurst = false
    @State private var confetti = false
    @State private var pulse = false
    @State private var busy = false

    private var done: Bool { step >= climbs.count }
    private var current: LessonClimb? { done ? nil : climbs[step] }

    var body: some View {
        VStack(spacing: 14) {
            coachLine
            climbStage
            loggedTray
            Spacer(minLength: 6)
            if showSelector, let current {
                AttemptBubbleSelector(
                    accentColor: current.outcome.color,
                    minimumAttempts: current.outcome.minAttempts
                ) { tries in
                    logCurrent(tries: tries)
                }
                .padding(.horizontal, 24)
            }
            if !done {
                outcomeButtonsRow
            }
        }
        .overlay(ConfettiView(isActive: $confetti).allowsHitTesting(false))
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.9), trigger: flashBurst)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.7), trigger: logged.count)
        .sensoryFeedback(.success, trigger: confetti)
        .onAppear { pulse = true }
    }

    // MARK: Coach line

    private var coachLine: some View {
        Text(LocalizedStringKey(current?.coach ?? Self.doneCoach))
            .font(.subheadline)
            .fontDesign(.rounded)
            .foregroundStyle(Color.geckoSecondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(minHeight: 58)
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
    }

    // MARK: Climb stage

    /// The climb waiting to be logged, shown as an oversized hold-shaped chip.
    /// On log it shrinks toward the tray below; the next climb slides in.
    private var climbStage: some View {
        ZStack {
            if let current {
                let numeric = VGrade.numeric(for: current.grade)
                let fill = Color.gradeColor(for: numeric)
                Text(GradeDisplaySettings.shared.label(forStored: current.grade))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VGrade.textColor(for: numeric))
                    .frame(width: 150, height: 78)
                    .background(GeckoHoldShape().fill(fill))
                    .brightness(flashBurst ? 0.22 : 0)
                    .shadow(color: fill.opacity(flashBurst ? 0.8 : 0.35),
                            radius: flashBurst ? 22 : 10, x: 0, y: 4)
                    .overlay {
                        if flashBurst {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 46, weight: .black))
                                .foregroundStyle(Color.geckoFlashGold)
                                .shadow(color: .geckoFlashGold.opacity(0.8), radius: 12)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.15, anchor: .bottom).combined(with: .opacity)
                    ))
            } else {
                doneBadge
            }
        }
        .frame(height: 92)
    }

    private var doneBadge: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.geckoSentGreen)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.geckoSentGreen.opacity(0.45), radius: 12, x: 0, y: 4)
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.geckoOnPrimary)
            }
            Text("\(logged.count) climbs · \(logged.filter { $0.outcome.isCompleted }.count) sends · ⚡ \(logged.filter { $0.outcome == .flash }.count) flash")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.geckoSecondaryText)
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    // MARK: Logged tray

    private var loggedTray: some View {
        HStack(spacing: 16) {
            ForEach(logged) { climb in
                VStack(spacing: 4) {
                    ClimbChipView(grade: climb.grade, outcome: climb.outcome)
                    Text(climb.outcome == .attempt
                         ? climb.outcome.label
                         : "\(climb.outcome.label) · \(climb.tries) \(climb.tries == 1 ? "try" : "tries")")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.geckoSecondaryText)
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .frame(minHeight: 46)
    }

    // MARK: Outcome buttons

    private var outcomeButtonsRow: some View {
        HStack(spacing: 10) {
            lessonButton(.flash, icon: "bolt.fill", label: "FLASH", subtitle: "1 try")
            lessonButton(.sent, icon: "checkmark", label: "SENT", subtitle: "2+ tries")
            lessonButton(.attempt, icon: "arrow.trianglehead.counterclockwise", label: "ATTEMPT", subtitle: "no send yet")
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func lessonButton(_ outcome: ClimbOutcome, icon: String, label: String, subtitle: String) -> some View {
        // A used button is gone for good. The row thins out as the lesson
        // progresses, so the last step is a single obvious target.
        if !logged.contains(where: { $0.outcome == outcome }) {
            let isActive = current?.outcome == outcome
            Button {
                handleTap(outcome)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                    Text(label)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(outcome.color.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 64)
                .foregroundStyle(outcome.color)
                .background(outcome.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(outcome.color.opacity(isActive ? 0.6 : 0.3), lineWidth: isActive ? 2 : 1.5)
                )
            }
            .buttonStyle(.plain)
            .bouncePress()
            .disabled(!isActive || busy)
            .opacity(isActive ? 1 : 0.35)
            .shadow(color: isActive ? outcome.color.opacity(pulse ? 0.5 : 0.15) : .clear,
                    radius: pulse ? 12 : 5, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .transition(.asymmetric(
                insertion: .identity,
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }

    // MARK: Logging

    private func handleTap(_ outcome: ClimbOutcome) {
        guard !busy else { return }
        switch outcome {
        case .flash:
            // The signature beat: the grade literally flashes before it logs.
            busy = true
            withAnimation(.geckoBounce) { flashBurst = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.geckoSpring) { flashBurst = false }
                logCurrent(tries: 1)
                busy = false
            }
        case .sent, .attempt:
            withAnimation(.geckoSnappy) { showSelector = true }
        }
    }

    private func logCurrent(tries: Int) {
        guard let current else { return }
        withAnimation(.geckoSpring) {
            logged.append(LoggedClimb(id: step, grade: current.grade,
                                      outcome: current.outcome, tries: tries))
            showSelector = false
            step += 1
        }
        if step >= climbs.count {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                confetti = true
                AnalyticsService.capture(.onboardingLessonCompleted)
                onComplete()
            }
        }
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
