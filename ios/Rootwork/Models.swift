import Foundation
import SwiftData

/// Anything you write: prayers, reflections, confessions, vows, verses you want to keep.
@Model final class Entry {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case prayer, reflection, confession, vow, verse
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var symbol: String {
            switch self {
            case .prayer: "hands.and.sparkles"
            case .reflection: "lightbulb"
            case .confession: "lock"
            case .vow: "checkmark.seal"
            case .verse: "book"
            }
        }
        var placeholder: String {
            switch self {
            case .prayer: "Father…"
            case .reflection: "What is he showing you?"
            case .confession: "Lord, I confess… (private)"
            case .vow: "Today I commit to…"
            case .verse: "A verse to keep…"
            }
        }
    }

    var createdAt: Date
    var kindRaw: String
    var text: String
    /// Moment tags (grief, anxiety, temptation…) let the app bring this back at the right time.
    var tags: [String]
    var sharedWith: [String]
    var verseRef: String?

    var kind: Kind { Kind(rawValue: kindRaw) ?? .prayer }

    init(_ kind: Kind, _ text: String, tags: [String] = [], createdAt: Date = .now, sharedWith: [String] = [], verseRef: String? = nil) {
        self.kindRaw = kind.rawValue
        self.text = text
        self.tags = tags
        self.createdAt = createdAt
        self.sharedWith = sharedWith
        self.verseRef = verseRef
    }
}

/// One day of Rootwork. Completion drives the streak and opens the Gate.
@Model final class DayRecord {
    @Attribute(.unique) var day: Date
    var stepsDone: [String]
    var verseRef: String?
    var verseText: String?
    var chapterRef: String?
    var aboutGod: String
    var aboutMe: String
    var action: String
    var prayback: String
    var completedAt: Date?
    var nightWatchAt: Date?

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
        self.stepsDone = []
        self.aboutGod = ""; self.aboutMe = ""; self.action = ""; self.prayback = ""
    }

    var isComplete: Bool { completedAt != nil }
    var steps: [RootworkStep] { stepsDone.compactMap(RootworkStep.init(rawValue:)) }
    var ringProgress: [Int] { Trinity.allCases.map { t in steps.filter { $0.ring == t }.count } }

    func mark(_ step: RootworkStep) {
        if !stepsDone.contains(step.rawValue) { stepsDone.append(step.rawValue) }
    }

    /// Today's record, created if it doesn't exist yet.
    static func today(in ctx: ModelContext) -> DayRecord {
        let day = Calendar.current.startOfDay(for: .now)
        if let r = try? ctx.fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { $0.day == day })).first { return r }
        let r = DayRecord(day: day)
        ctx.insert(r)
        return r
    }
}

/// A verse hidden in the heart.
@Model final class SwordVerse {
    @Attribute(.unique) var ref: String
    var text: String
    var addedAt: Date
    var memorizedAt: Date?

    init(ref: String, text: String, addedAt: Date = .now) {
        self.ref = ref; self.text = text; self.addedAt = addedAt
    }
}

/// Highlight and/or note on a single verse in the reader.
@Model final class Mark {
    @Attribute(.unique) var ref: String
    var color: String?
    var note: String?
    init(ref: String, color: String? = nil, note: String? = nil) { self.ref = ref; self.color = color; self.note = note }
}

/// Someone you pray for.
@Model final class Person {
    var name: String
    var relation: String
    var requests: String
    var lastPrayedAt: Date?
    var isBrother: Bool          // one of your three sharing slots
    var createdAt: Date

    init(name: String, relation: String = "", requests: String = "", isBrother: Bool = false) {
        self.name = name; self.relation = relation; self.requests = requests
        self.isBrother = isBrother; self.createdAt = .now
    }

    var prayedToday: Bool { lastPrayedAt.map(Calendar.current.isDateInToday) ?? false }
}

// MARK: - Rhythm

enum RootworkStep: String, CaseIterable, Identifiable {
    case pray, read, verse, reflect, action, prayback
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pray: "Pray first"
        case .read: "Read one chapter"
        case .verse: "Write one verse"
        case .reflect: "About God, about me"
        case .action: "One action today"
        case .prayback: "Pray it back"
        }
    }

    /// Which ring this step fills: the day begins and ends in prayer.
    var ring: Trinity {
        switch self {
        case .pray, .prayback: .father
        case .read: .son
        case .verse, .reflect, .action: .spirit
        }
    }
}

enum Rank: String, CaseIterable {
    case seeker, follower, disciple, laborer, ambassador, elder
    var threshold: Int { [0, 50, 200, 500, 1000, 2000][Rank.allCases.firstIndex(of: self)!] }
    var title: String { rawValue.capitalized }
    var verse: String {
        switch self {
        case .seeker: "Seek, and you will find. Matthew 7:7"
        case .follower: "Follow me. Matthew 4:19"
        case .disciple: "If you remain in my word, you are truly my disciples. John 8:31"
        case .laborer: "The harvest is plentiful, but the laborers are few. Luke 10:2"
        case .ambassador: "We are ambassadors on behalf of Christ. 2 Corinthians 5:20"
        case .elder: "Be an example to those who believe. 1 Timothy 4:12"
        }
    }
    static func of(fruit: Int) -> Rank { allCases.last { fruit >= $0.threshold } ?? .seeker }
    var next: Rank? { let i = Rank.allCases.firstIndex(of: self)!; return i + 1 < Rank.allCases.count ? Rank.allCases[i + 1] : nil }
}

enum Fruit {
    static let rootwork = 10, nightWatch = 3, sharedPrayer = 2, verseMemorized = 15

    static func total(days: [DayRecord], entries: [Entry], swords: [SwordVerse]) -> Int {
        days.filter(\.isComplete).count * rootwork
            + days.filter { $0.nightWatchAt != nil }.count * nightWatch
            + entries.filter { !$0.sharedWith.isEmpty }.count * sharedPrayer
            + swords.filter { $0.memorizedAt != nil }.count * verseMemorized
    }
}

// MARK: - Streak with mercy

/// A streak that forgives one missed day per rolling week, as long as you come back the next day.
/// "His mercies are new every morning" (Lam 3:22–23). Shame-based streaks send people away.
enum Streak {
    struct Result: Equatable { var days: Int; var mercyDays: [Date] }

    static func compute(completedDays: Set<Date>, today: Date = .now, calendar: Calendar = .current) -> Result {
        let start = calendar.startOfDay(for: today)
        var cursor = completedDays.contains(start) ? start : calendar.date(byAdding: .day, value: -1, to: start)!
        var days = 0
        var mercy: [Date] = []

        while true {
            if completedDays.contains(cursor) {
                days += 1
            } else {
                let before = calendar.date(byAdding: .day, value: -1, to: cursor)!
                // mercy holds later dates (we walk backwards); allow one per 7-day window
                let weekAhead = calendar.date(byAdding: .day, value: 7, to: cursor)!
                let recentMercy = mercy.contains { $0 < weekAhead }
                guard days > 0, !recentMercy, completedDays.contains(before) else { break }
                mercy.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return Result(days: days, mercyDays: mercy)
    }
}
