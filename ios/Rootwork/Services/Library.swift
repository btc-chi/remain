import Foundation
import Observation

/// Bundled content: verse texts (WEB), the verse-of-the-day rotation, Sword moments, and the walking guide.
@MainActor @Observable final class Library {
    let verses: [String: String]
    let votdRefs: [String]
    let moments: [Moment]
    let guide: [Article]

    /// Landscapes behind the verse of the day. Add generated landscapes here as asset names.
    static let landscapes = ["verse", "father"]

    init() {
        verses = Self.load("verses") ?? [:]
        votdRefs = Self.load("votd") ?? ["John 15:4"]
        moments = Self.load("sword") ?? []
        guide = Self.load("guide") ?? []
    }

    func text(_ ref: String) -> String { verses[ref] ?? "" }

    struct DailyVerse { let ref: String; let text: String; let art: String }

    func verseOfTheDay(_ date: Date = .now) -> DailyVerse {
        let n = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let ref = votdRefs[n % votdRefs.count]
        return DailyVerse(ref: ref, text: text(ref), art: Self.landscapes[n % Self.landscapes.count])
    }

    /// One memory verse per week, from the same rotation, picking short ones.
    func memoryVerse(_ date: Date = .now) -> DailyVerse {
        let short = votdRefs.filter { text($0).count < 140 }
        let week = Calendar.current.ordinality(of: .weekOfYear, in: .era, for: date) ?? 0
        let ref = short.isEmpty ? "Psalm 119:11" : short[week % short.count]
        return DailyVerse(ref: ref, text: text(ref), art: "spirit")
    }

    func moment(tag: String) -> Moment? { moments.first { $0.tag == tag } }

    private static func load<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// "What are you facing?" A moment and the verses that fight it.
struct Moment: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let tag: String
    let refs: [String]
}

/// One section of the walking guide.
struct Article: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let note: String
    let blocks: [Block]

    struct Block: Codable, Hashable {
        let type: String          // paragraph, heading, scripture, note, list, steps, rows, map
        var text: String?
        var ref: String?
        var caption: String?
        var lead: Bool?
        var dim: Bool?
        var items: [String]?
        var rows: [Row]?
    }

    struct Row: Codable, Hashable { let label: String; let text: String }
}
