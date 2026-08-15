import Foundation
import PostHog

enum AnalyticsEvent: String {
    case signUp = "sign_up"
    case signIn = "sign_in"
    case signInFailed = "sign_in_failed"
    case signOut = "sign_out"
    case sessionLogged = "session_logged"
    case postLiked = "post_liked"
    case postUnliked = "post_unliked"
    case feedLoaded = "feed_loaded"
    case climbAdded = "climb_added"
    case commentAdded = "comment_added"
    case commentDeleted = "comment_deleted"
    case userFollowed = "user_followed"
    case userUnfollowed = "user_unfollowed"
    case feedRailSwitched = "feed_rail_switched"
    case postReported = "post_reported"
    case userBlocked = "user_blocked"
    case userUnblocked = "user_unblocked"
    case accountDeleted = "account_deleted"
    case onboardingStarted = "onboarding_started"
    case onboardingPageViewed = "onboarding_page_viewed"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case onboardingReplayed = "onboarding_replayed"
}

enum AnalyticsService {
    static func configure() {
        let config = PostHogConfig(
            apiKey: "phc_EzY4yVFsnOgaYb1hM6vIRacop6uT2KKAtTwxGuIaNv",
            host: "https://us.i.posthog.com"
        )
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
    }

    static func identify(userId: String, properties: [String: Any] = [:]) {
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }

    static func capture(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
