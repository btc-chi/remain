import Foundation
import Observation
import AVFoundation

struct Verse: Identifiable, Hashable, Codable {
    let book: String
    let chapter: Int
    let number: Int
    let text: String
    var id: String { ref }
    var ref: String { "\(book) \(chapter):\(number)" }
}

struct Chapter: Hashable, Codable {
    let book: String
    let number: Int
    let verses: [Verse]
    var title: String { "\(book) \(number)" }
}

struct Book: Hashable, Identifiable {
    let name: String
    let chapters: Int
    let testament: Testament
    var id: String { name }
    enum Testament { case old, new }
}

/// Prototype source: bible-api.com (World English Bible, public domain, no key), cached on disk for offline reading.
/// Production: swap in the YouVersion Platform Swift SDK for NIV/ESV and 1,400+ licensed versions.
@MainActor @Observable final class BibleService {
    var translation = "web"
    private var memory: [String: Chapter] = [:]

    static let books: [Book] = {
        let old: [(String, Int)] = [("Genesis", 50), ("Exodus", 40), ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34),
            ("Joshua", 24), ("Judges", 21), ("Ruth", 4), ("1 Samuel", 31), ("2 Samuel", 24), ("1 Kings", 22), ("2 Kings", 25),
            ("1 Chronicles", 29), ("2 Chronicles", 36), ("Ezra", 10), ("Nehemiah", 13), ("Esther", 10), ("Job", 42),
            ("Psalms", 150), ("Proverbs", 31), ("Ecclesiastes", 12), ("Song of Solomon", 8), ("Isaiah", 66), ("Jeremiah", 52),
            ("Lamentations", 5), ("Ezekiel", 48), ("Daniel", 12), ("Hosea", 14), ("Joel", 3), ("Amos", 9), ("Obadiah", 1),
            ("Jonah", 4), ("Micah", 7), ("Nahum", 3), ("Habakkuk", 3), ("Zephaniah", 3), ("Haggai", 2), ("Zechariah", 14), ("Malachi", 4)]
        let new: [(String, Int)] = [("Matthew", 28), ("Mark", 16), ("Luke", 24), ("John", 21), ("Acts", 28), ("Romans", 16),
            ("1 Corinthians", 16), ("2 Corinthians", 13), ("Galatians", 6), ("Ephesians", 6), ("Philippians", 4), ("Colossians", 4),
            ("1 Thessalonians", 5), ("2 Thessalonians", 3), ("1 Timothy", 6), ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1),
            ("Hebrews", 13), ("James", 5), ("1 Peter", 5), ("2 Peter", 3), ("1 John", 5), ("2 John", 1), ("3 John", 1), ("Jude", 1),
            ("Revelation", 22)]
        return old.map { Book(name: $0.0, chapters: $0.1, testament: .old) } + new.map { Book(name: $0.0, chapters: $0.1, testament: .new) }
    }()

    static func book(_ name: String) -> Book? { books.first { $0.name == name } }

    /// The walking guide's plan: his life, then how to live, then the foundation.
    static let plan: [(book: String, chapters: Int)] = [
        ("Luke", 24), ("Acts", 28), ("John", 21), ("Mark", 16),
        ("Romans", 16), ("Galatians", 6), ("Ephesians", 6), ("Philippians", 4), ("James", 5), ("1 John", 5),
        ("Genesis", 50), ("Exodus", 40),
        ("Matthew", 28), ("1 Corinthians", 16), ("2 Corinthians", 13), ("Colossians", 4), ("1 Thessalonians", 5),
        ("2 Thessalonians", 3), ("1 Timothy", 6), ("2 Timothy", 4), ("Titus", 3), ("Philemon", 1), ("Hebrews", 13),
        ("1 Peter", 5), ("2 Peter", 3), ("2 John", 1), ("3 John", 1), ("Jude", 1), ("Revelation", 22),
        ("Leviticus", 27), ("Numbers", 36), ("Deuteronomy", 34), ("Isaiah", 66),
    ]

    static func next(after book: String, _ chapter: Int, in list: [Book] = books) -> (String, Int)? {
        guard let i = list.firstIndex(where: { $0.name == book }) else { return nil }
        if chapter < list[i].chapters { return (book, chapter + 1) }
        return i + 1 < list.count ? (list[i + 1].name, 1) : nil
    }

    static func previous(before book: String, _ chapter: Int, in list: [Book] = books) -> (String, Int)? {
        guard let i = list.firstIndex(where: { $0.name == book }) else { return nil }
        if chapter > 1 { return (book, chapter - 1) }
        return i > 0 ? (list[i - 1].name, list[i - 1].chapters) : nil
    }

    func chapter(_ book: String, _ number: Int) async throws -> Chapter {
        let key = "\(book) \(number) \(translation)"
        if let hit = memory[key] { return hit }
        let file = Self.cacheDir.appending(path: key.replacingOccurrences(of: " ", with: "_") + ".json")
        if let data = try? Data(contentsOf: file), let cached = try? JSONDecoder().decode(Chapter.self, from: data) {
            memory[key] = cached
            return cached
        }
        let decoded = try await fetch("\(book) \(number)")
        let chapter = Chapter(book: book, number: number, verses: decoded.verses.map {
            Verse(book: book, chapter: $0.chapter, number: $0.verse, text: Self.clean($0.text))
        })
        memory[key] = chapter
        try? JSONEncoder().encode(chapter).write(to: file)
        return chapter
    }

    func passage(_ ref: String) async throws -> String {
        Self.clean(try await fetch(ref).text)
    }

    /// "jn 3 16", "1 cor 13", "Psalm 23:1" → (book, chapter, verse?)
    static func parse(_ query: String) -> (book: String, chapter: Int, verse: Int?)? {
        let q = query.lowercased().replacingOccurrences(of: ":", with: " ").replacingOccurrences(of: ".", with: " ")
        let parts = q.split(separator: " ").map(String.init)
        let numbers = parts.reversed().prefix { Int($0) != nil }.reversed().compactMap(Int.init)
        let name = parts.dropLast(numbers.count).joined(separator: " ")
        guard !name.isEmpty else { return nil }
        let squashed = name.replacingOccurrences(of: " ", with: "")
        let match = books.first { $0.name.lowercased().replacingOccurrences(of: " ", with: "").hasPrefix(squashed) }
            ?? (squashed == "psalm" ? book("Psalms") : nil)
        guard let b = match else { return nil }
        let chapter = min(max(numbers.first ?? 1, 1), b.chapters)
        return (b.name, chapter, numbers.count > 1 ? numbers[1] : nil)
    }

    // MARK: - private

    private func fetch(_ ref: String) async throws -> APIResponse {
        let path = ref.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let url = URL(string: "https://bible-api.com/\(path)?translation=\(translation)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(APIResponse.self, from: data)
    }

    private static func clean(_ s: String) -> String { s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    private static let cacheDir: URL = {
        let dir = URL.cachesDirectory.appending(path: "chapters")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private struct APIResponse: Decodable {
        struct V: Decodable { let chapter: Int; let verse: Int; let text: String }
        let verses: [V]
        let text: String
    }
}

/// Read-aloud for auditory learners. Follows along verse by verse.
@MainActor @Observable final class ScriptureReader: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var queue: [Verse] = []
    var current: Verse?
    var isSpeaking: Bool { current != nil }

    override init() { super.init(); synth.delegate = self }

    func play(_ verses: [Verse], from start: Int = 1) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        queue = verses.filter { $0.number >= start }
        speakNext()
    }

    func speak(_ text: String) {
        play([Verse(book: "", chapter: 0, number: 1, text: text)])
    }

    func stop() {
        queue = []; current = nil
        synth.stopSpeaking(at: .immediate)
    }

    private func speakNext() {
        guard !queue.isEmpty else { current = nil; return }
        let v = queue.removeFirst()
        current = v
        let u = AVSpeechUtterance(string: v.text)
        u.rate = 0.47
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in if self.current != nil { self.speakNext() } }
    }
}
