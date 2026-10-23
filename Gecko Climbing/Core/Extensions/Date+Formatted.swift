import Foundation

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var sessionDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }

    var dayMonthFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }
}

extension Int {
    var durationFormatted: String {
        let hours = self / 60
        let minutes = self % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Crew recency

extension Date {
    /// Ultra-short recency for presence strips: "Today", "1d", "6d". Past a
    /// week the strip doesn't show the climber at all, so there's no longer
    /// form.
    var crewRecency: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: self), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        if days <= 0 { return "Today" }
        return "\(days)d"
    }

    /// Sentence-friendly recency for crew rows: "today", "yesterday",
    /// "3 days ago", "2 weeks ago".
    var crewRecencySentence: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: self), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2...13: return "\(days) days ago"
        case 14...59: return "\(days / 7) weeks ago"
        default: return "\(days / 30) months ago"
        }
    }
}
