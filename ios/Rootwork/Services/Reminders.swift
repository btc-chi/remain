import Foundation
import UserNotifications

/// The touchpoints that pull you back in: a morning verse (different each day), an evening nudge, and Night watch.
enum Reminders {
    static let morningKey = "reminder.morning", eveningKey = "reminder.evening", nightKey = "reminder.night"

    static func defaultTime(_ hour: Int, _ minute: Int = 0) -> Double {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute))!.timeIntervalSinceReferenceDate
    }

    @MainActor static func reschedule(library: Library) {
        let d = UserDefaults.standard
        let morning = time(d.object(forKey: morningKey) as? Double ?? defaultTime(6))
        let evening = time(d.object(forKey: eveningKey) as? Double ?? defaultTime(18, 30))
        let night = time(d.object(forKey: nightKey) as? Double ?? defaultTime(21, 30))
        let verses = (0..<7).map { library.verseOfTheDay(Calendar.current.date(byAdding: .day, value: $0, to: .now)!) }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            center.removeAllPendingNotificationRequests()
            // Seven mornings ahead, each with that day's verse. Rescheduled every launch.
            for (i, v) in verses.enumerated() {
                let day = Calendar.current.date(byAdding: .day, value: i, to: .now)!
                var c = Calendar.current.dateComponents([.year, .month, .day], from: day)
                c.hour = morning.hour; c.minute = morning.minute
                add(center, id: "morning-\(i)", components: c, repeats: false, title: v.ref, body: v.text)
            }
            add(center, id: "evening", components: evening, repeats: true,
                title: "Your rings are waiting",
                body: "Twenty minutes with the Father. Mercy covers one missed day, not two.")
            add(center, id: "night", components: night, repeats: true,
                title: "Night watch", body: "Thank him, confess, lay it down, sleep.")
        }
    }

    private static func time(_ interval: Double) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSinceReferenceDate: interval))
    }

    private static func add(_ c: UNUserNotificationCenter, id: String, components: DateComponents, repeats: Bool, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
