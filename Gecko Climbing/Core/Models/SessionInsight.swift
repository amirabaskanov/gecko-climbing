import SwiftUI

/// A single insight generated after completing a session
struct SessionInsight: Identifiable {
    let id = UUID()
    let kind: Kind
    let title: String
    let description: String
    let icon: String
    let accentColor: Color

    enum Kind {
        case personalBest
        case trend
        case milestone
        case encouragement
    }
}
