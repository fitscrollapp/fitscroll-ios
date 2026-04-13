import Foundation

enum TimeFormatter {
    static func formatDuration(seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    static func formatMinutes(_ minutes: Double) -> String {
        if minutes < 1 {
            return String(format: "%.0f sec", minutes * 60)
        } else if minutes == Double(Int(minutes)) {
            return "\(Int(minutes)) min"
        } else {
            return String(format: "%.1f min", minutes)
        }
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
