import Foundation

/// The app writes a small snapshot to the App Group; widgets read it.
struct WidgetSnapshot: Codable {
    var day: Date
    var progress: [Int]          // Pray, Read, Write
    var streak: Int
    var verseRef: String
    var verseText: String

    static let placeholder = WidgetSnapshot(day: .now, progress: [1, 1, 1], streak: 7,
                                            verseRef: "John 15:4", verseText: "Remain in me, and I in you.")

    /// Progress resets at midnight even if the app hasn't been opened.
    var progressForToday: [Int] { Calendar.current.isDateInToday(day) ? progress : [0, 0, 0] }
}

enum WidgetBridge {
    static let appGroup = "group.app.rootwork"
    private static let key = "widget.snapshot"

    static func read() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .placeholder }
        return s
    }

    static func write(_ s: WidgetSnapshot) {
        UserDefaults(suiteName: appGroup)?.set(try? JSONEncoder().encode(s), forKey: key)
    }
}
