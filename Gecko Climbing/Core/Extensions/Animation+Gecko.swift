import SwiftUI

extension Animation {
    /// Standard spring for most interactions
    static let geckoSpring = Animation.spring(response: 0.35, dampingFraction: 0.7)

    /// Quick snappy spring for toggles and selection
    static let geckoSnappy = Animation.spring(response: 0.25, dampingFraction: 0.8)

    /// Bouncier spring for celebrations
    static let geckoBounce = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// Staggered delay based on index
    static func geckoStagger(index: Int) -> Animation {
        .geckoSpring.delay(Double(index) * 0.05)
    }
}
