import SwiftUI
import SwiftData

/// "Take the sword of the Spirit, which is the word of God." Ephesians 6:17
/// What are you facing? Verses for that moment, next to what you wrote when you faced it.
struct SwordView: View {
    @Environment(Library.self) private var library
    @Query(sort: \SwordVerse.addedAt, order: .reverse) private var saved: [SwordVerse]
    @State private var practicing: Library.DailyVerse?

    var body: some View {
        let memory = library.memoryVerse()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Button { practicing = memory } label: {
                        ZStack(alignment: .bottomLeading) {
                            ArtBackground(art: "spirit")
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Memory verse · this week").font(.footnote.weight(.semibold)).opacity(0.85)
                                Text(memory.text).font(Fonts.word(22)).lineLimit(4).multilineTextAlignment(.leading)
                                HStack {
                                    Text(memory.ref).font(.subheadline.bold())
                                    Spacer()
                                    Label("Practice", systemImage: "play.fill").font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .glassEffect(.regular.interactive(), in: .capsule)
                                }
                            }
                            .foregroundStyle(.white).padding(18)
                        }
                        .frame(height: 260).clipShape(.rect(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)

                    SectionHeader(title: "What are you facing?")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(library.moments) { m in
                            NavigationLink(value: m) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: m.symbol).font(.title3).foregroundStyle(Trinity.son.color)
                                    Text(m.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                                        .lineLimit(2, reservesSpace: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !saved.isEmpty {
                        SectionHeader(title: "Hidden in your heart", trailing: "\(saved.count)")
                        VStack(spacing: 0) {
                            ForEach(saved) { v in
                                Button { practicing = .init(ref: v.ref, text: v.text, art: "spirit") } label: {
                                    HStack(alignment: .top) {
                                        ScriptureBlock(ref: v.ref, text: v.text, size: 17)
                                        Spacer()
                                        if v.memorizedAt != nil {
                                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Trinity.father.color)
                                        }
                                    }
                                    .padding(16)
                                }
                                .buttonStyle(.plain)
                                if v.id != saved.last?.id { Divider().padding(.leading, 16) }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .groupedBackground()
            .navigationTitle("Sword")
            .navigationDestination(for: Moment.self) { MomentView(moment: $0) }
            .fullScreenCover(item: $practicing) { MemorizeView(verse: $0) }
        }
    }
}

extension Library.DailyVerse: Identifiable { var id: String { ref } }

struct MomentView: View {
    let moment: Moment
    @Environment(Library.self) private var library
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var praying: PrayerScript?

    var body: some View {
        let mine = entries.filter { $0.tags.contains(moment.tag) && $0.kind != .confession }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(moment.refs, id: \.self) { ref in
                    Card {
                        ScriptureBlock(ref: ref, text: library.text(ref), size: 20)
                        HStack {
                            Button("Pray this", systemImage: "hands.and.sparkles") { praying = .verse(ref: ref, text: library.text(ref)) }
                            ShareLink(item: "“\(library.text(ref))” \(ref)") { Label("Share", systemImage: "square.and.arrow.up") }
                        }
                        .buttonStyle(.bordered).buttonBorderShape(.capsule).font(.subheadline).tint(.primary)
                    }
                }
                if !mine.isEmpty {
                    SectionHeader(title: "When you faced this")
                    ForEach(mine.prefix(5)) { e in
                        Card {
                            Text("\(e.kind.label) · \(e.createdAt.formatted(.dateTime.month(.wide).day()))")
                                .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            Text(e.text).font(Fonts.word(18))
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .groupedBackground()
        .navigationTitle(moment.name)
        .fullScreenCover(item: $praying) { PrayerSessionView(script: $0) }
    }
}

/// Hide the word in your heart: each round hides more words until you can say it from memory.
struct MemorizeView: View {
    let verse: Library.DailyVerse
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var saved: [SwordVerse]
    @State private var round = 0
    @State private var revealed: Set<Int> = []

    private var words: [String] { verse.text.split(separator: " ").map(String.init) }
    private static let rounds = [0.0, 0.3, 0.6, 1.0]   // share of words hidden

    /// Deterministic: the same words hide each round, and each round hides more.
    private var hidden: Set<Int> {
        let share = Self.rounds[round]
        let ranked = words.indices.sorted { ($0 * 7919) % 101 < ($1 * 7919) % 101 }
        return Set(ranked.prefix(Int((Double(words.count) * share).rounded())))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text(["Read it aloud.", "Fill in the gaps.", "Most of it, from memory.", "All of it, from memory."][round])
                    .font(.title2.bold())
                FlowLayout(spacing: 7) {
                    ForEach(words.indices, id: \.self) { i in
                        let isHidden = hidden.contains(i) && !revealed.contains(i)
                        Text(words[i])
                            .font(Fonts.word(26))
                            .foregroundStyle(isHidden ? .clear : .primary)
                            .overlay(alignment: .bottom) {
                                if isHidden { Capsule().fill(Trinity.son.color).frame(height: 3).offset(y: -4) }
                            }
                            .onTapGesture { revealed.insert(i) }
                    }
                }
                Text(verse.ref).font(.headline).foregroundStyle(Trinity.son.color)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Self.rounds.indices, id: \.self) { i in
                        Capsule().fill(i <= round ? Trinity.son.color : Color(.tertiarySystemFill)).frame(height: 5)
                    }
                }
                Button { next() } label: {
                    Text(round < Self.rounds.count - 1 ? "Next round" : "I know it").font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(24)
            .animation(.smooth, value: round)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } } }
        }
    }

    private func next() {
        revealed = []
        if round < Self.rounds.count - 1 { round += 1; return }
        let v = saved.first { $0.ref == verse.ref } ?? { let n = SwordVerse(ref: verse.ref, text: verse.text); ctx.insert(n); return n }()
        if v.memorizedAt == nil { v.memorizedAt = .now }
        try? ctx.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Wrapping layout for word-by-word text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += line + spacing; line = 0 }
            x += size.width + spacing; line = max(line, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += line + spacing; line = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing; line = max(line, size.height)
        }
    }
}
