import SwiftUI
import SwiftData

/// The reader. Book and version up top, big New York text, floating previous / play / next controls,
/// and a verse panel for highlight, note, Sword, copy, share and pray.
struct BibleView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(BibleService.self) private var bible
    @Environment(ScriptureReader.self) private var reader
    @Environment(AppNavigation.self) private var nav
    @Query private var marks: [Mark]
    @Query private var swords: [SwordVerse]

    @AppStorage("plan.book") private var planBook = "Luke"
    @AppStorage("plan.chapter") private var planChapter = 10
    @AppStorage("reader.book") private var book = "Luke"
    @AppStorage("reader.chapter") private var number = 10
    @AppStorage("reader.size") private var textSize = 20.0

    @State private var chapter: Chapter?
    @State private var failed = false
    @State private var selected: Verse?
    @State private var scrollTarget: Int?
    @State private var showPicker = false
    @State private var showSearch = false
    @State private var noteDraft = ""
    @State private var editingNote = false
    @State private var praying: PrayerScript?
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if book == planBook && number == planChapter {
                            Label("Today's chapter", systemImage: "sun.max.fill")
                                .font(.footnote.weight(.semibold)).foregroundStyle(Trinity.father.color)
                        }
                        Text(book).font(Fonts.word(17, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 8)
                        Text("\(number)").font(Fonts.word(64, weight: .semibold)).padding(.bottom, 8)
                        if let chapter {
                            ChapterText(verses: chapter.verses, selected: selected?.number, speaking: reader.current?.number,
                                        marks: Dictionary(marks.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a }),
                                        size: textSize) { v in
                                withAnimation(.snappy) { selected = selected == v ? nil : v }
                            }
                            Text("World English Bible · public domain").font(.caption).foregroundStyle(.tertiary).padding(.top, 24)
                        } else if failed {
                            ContentUnavailableView("Couldn't load \(book) \(number)", systemImage: "wifi.slash",
                                                   description: Text("Check your connection. Chapters you've opened before work offline."))
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(80)
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 140)
                }
                .onChange(of: scrollTarget) { _, n in
                    guard let n else { return }
                    withAnimation { proxy.scrollTo("v\(n)", anchor: .center) }
                    scrollTarget = nil
                }
                .onChange(of: reader.current?.number) { _, n in
                    if let n { withAnimation { proxy.scrollTo("v\(n)", anchor: .center) } }
                }
            }
            .background(Color(.systemBackground))
            .toolbar { toolbar }
            .overlay(alignment: .bottom) {
                if let v = selected { verseActions(v).transition(.move(edge: .bottom).combined(with: .opacity)) }
                else { pager }
            }
            .sheet(isPresented: $showPicker) {
                BookPicker { b, c in go(b, c) }.presentationDetents([.large])
            }
            .sheet(isPresented: $showSearch) {
                SearchSheet { b, c, v in go(b, c); scrollTarget = v }
            }
            .alert("Note on \(selected?.ref ?? "")", isPresented: $editingNote) {
                TextField("What is he saying to you here?", text: $noteDraft, axis: .vertical)
                Button("Save") { saveMark { $0.note = noteDraft.isEmpty ? nil : noteDraft } }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(item: $praying) { PrayerSessionView(script: $0) }
            .navigationDestination(isPresented: $showGuide) { GuideView() }
            .task(id: "\(book) \(number)") { await load() }
            .onChange(of: nav.open, initial: true) { _, loc in
                if let loc { go(loc.book, loc.chapter); nav.open = nil }
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button("\(book) \(number)") { showPicker = true }.fontWeight(.semibold)
            Menu("WEB") {
                Label("World English Bible", systemImage: "checkmark")
                Text("NIV, ESV and more arrive with YouVersion Platform")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Search", systemImage: "magnifyingglass") { showSearch = true }
            Menu("More", systemImage: "ellipsis") {
                Button("Walking guide", systemImage: "book.pages") { showGuide = true }
                Button("Go to today's chapter", systemImage: "sun.max") { go(planBook, planChapter) }
                Divider()
                Button("Larger text", systemImage: "textformat.size.larger") { textSize = min(30, textSize + 2) }
                Button("Smaller text", systemImage: "textformat.size.smaller") { textSize = max(15, textSize - 2) }
            }
        }
    }

    private var pager: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 20) {
                Button { step(-1) } label: { Image(systemName: "chevron.left").font(.title3.weight(.semibold)).frame(width: 50, height: 50) }
                    .glassEffect(.regular.interactive(), in: .circle)
                Button {
                    guard let chapter else { return }
                    reader.isSpeaking ? reader.stop() : reader.play(chapter.verses)
                } label: {
                    Image(systemName: reader.isSpeaking ? "pause.fill" : "play.fill").font(.title).frame(width: 64, height: 64)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(reader.isSpeaking ? "Stop reading aloud" : "Read aloud")
                Button { step(1) } label: { Image(systemName: "chevron.right").font(.title3.weight(.semibold)).frame(width: 50, height: 50) }
                    .glassEffect(.regular.interactive(), in: .circle)
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 12)
    }

    private func verseActions(_ v: Verse) -> some View {
        let mark = marks.first { $0.ref == v.ref }
        let inSword = swords.contains { $0.ref == v.ref }
        return VStack(spacing: 14) {
            HStack {
                Text(v.ref).font(.headline)
                Spacer()
                Button { withAnimation { selected = nil } } label: { Image(systemName: "xmark").font(.headline).frame(width: 30, height: 30) }
                    .buttonStyle(.glass).buttonBorderShape(.circle)
            }
            HStack(spacing: 12) {
                ForEach(Highlight.allCases) { h in
                    Button { saveMark { $0.color = mark?.color == h.rawValue ? nil : h.rawValue } } label: {
                        Circle().fill(h.swatch).frame(width: 34, height: 34)
                            .overlay { if mark?.color == h.rawValue { Image(systemName: "checkmark").font(.footnote.bold()) } }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            HStack(spacing: 0) {
                action("Note", mark?.note == nil ? "note.text" : "note.text.badge.plus") {
                    noteDraft = mark?.note ?? ""; editingNote = true
                }
                action(inSword ? "In Sword" : "Sword", inSword ? "shield.lefthalf.filled" : "shield") {
                    if !inSword { ctx.insert(SwordVerse(ref: v.ref, text: v.text)) }
                }
                action("Pray", "hands.and.sparkles") { praying = .verse(ref: v.ref, text: v.text) }
                action("Copy", "doc.on.doc") { UIPasteboard.general.string = "\(v.text) \(v.ref)" }
                ShareLink(item: "“\(v.text)” \(v.ref)") {
                    VStack(spacing: 6) { Image(systemName: "square.and.arrow.up").font(.title3); Text("Share").font(.caption) }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
        .padding(.horizontal, 10).padding(.bottom, 6)
    }

    private func action(_ title: String, _ symbol: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 6) { Image(systemName: symbol).font(.title3); Text(title).font(.caption) }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - helpers

    private func load() async {
        chapter = nil; failed = false
        do { chapter = try await bible.chapter(book, number) } catch { failed = true }
    }

    private func go(_ b: String, _ c: Int) {
        reader.stop(); selected = nil
        book = b; number = c
    }

    private func step(_ delta: Int) {
        let target = delta > 0 ? BibleService.next(after: book, number) : BibleService.previous(before: book, number)
        if let t = target { go(t.0, t.1) }
    }

    private func saveMark(_ change: (Mark) -> Void) {
        guard let v = selected else { return }
        let m = marks.first { $0.ref == v.ref } ?? { let n = Mark(ref: v.ref); ctx.insert(n); return n }()
        change(m)
        if m.color == nil && m.note == nil { ctx.delete(m) }
        try? ctx.save()
    }
}

enum Highlight: String, CaseIterable, Identifiable {
    case gold, rose, green, blue
    var id: String { rawValue }
    var swatch: Color {
        switch self {
        case .gold: Color(red: 1.0, green: 0.84, blue: 0.35)
        case .rose: Color(red: 1.0, green: 0.62, blue: 0.68)
        case .green: Color(red: 0.6, green: 0.88, blue: 0.6)
        case .blue: Color(red: 0.55, green: 0.8, blue: 1.0)
        }
    }
    var fill: Color { swatch.opacity(0.45) }
}

/// A chapter as tappable verses that read like one passage.
struct ChapterText: View {
    let verses: [Verse]
    var selected: Int?
    var speaking: Int?
    var marks: [String: Mark] = [:]
    var size: CGFloat = 19
    var onTap: (Verse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(verses) { v in
                let mark = marks[v.ref]
                (Text("\(v.number) ").font(.system(size: size * 0.55, weight: .semibold)).foregroundStyle(.secondary)
                 + Text(v.text).font(Fonts.word(size)))
                    .lineSpacing(size * 0.32)
                    .padding(.horizontal, 3).padding(.vertical, 2)
                    .background(background(v, mark), in: .rect(cornerRadius: 5))
                    .overlay(alignment: .topTrailing) {
                        if mark?.note != nil {
                            Image(systemName: "note.text").font(.caption2).foregroundStyle(Trinity.son.color).offset(x: 6, y: -4)
                        }
                    }
                    .underline(selected == v.number, pattern: .dot, color: Trinity.son.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .onTapGesture { onTap(v) }
                    .accessibilityAddTraits(.isButton)
                    .id("v\(v.number)")
            }
        }
    }

    private func background(_ v: Verse, _ m: Mark?) -> Color {
        if speaking == v.number { return Trinity.spirit.color.opacity(0.2) }
        if let c = m?.color, let h = Highlight(rawValue: c) { return h.fill }
        return .clear
    }
}

/// Books grouped by testament, then a grid of chapters.
struct BookPicker: View {
    let pick: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("New Testament") { rows(.new) }
                Section("Old Testament") { rows(.old) }
            }
            .navigationTitle("Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close", systemImage: "xmark") { dismiss() } } }
        }
    }

    private func rows(_ t: Book.Testament) -> some View {
        ForEach(BibleService.books.filter { $0.testament == t }) { b in
            NavigationLink(b.name) {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(1...b.chapters, id: \.self) { c in
                            Button { pick(b.name, c); dismiss() } label: {
                                Text("\(c)").font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .groupedBackground()
                .navigationTitle(b.name)
            }
        }
    }
}

/// Jump by reference ("jn 3 16"), or search the verses and guide that ship with the app.
struct SearchSheet: View {
    let go: (String, Int, Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(Library.self) private var library
    @State private var query = ""

    var body: some View {
        let parsed = BibleService.parse(query)
        let q = query.lowercased()
        let verseHits: [(key: String, value: String)] = q.count < 3 ? [] : library.verses.filter { $0.value.lowercased().contains(q) }.sorted { $0.key < $1.key }
        let articleHits: [Article] = q.count < 3 ? [] : library.guide.filter { a in
            a.title.lowercased().contains(q) || a.blocks.contains { ($0.text ?? "").lowercased().contains(q) }
        }
        NavigationStack {
            List {
                if let p = parsed {
                    Button { go(p.book, p.chapter, p.verse); dismiss() } label: {
                        Label("Go to \(p.book) \(p.chapter)\(p.verse.map { ":\($0)" } ?? "")", systemImage: "arrow.right.circle.fill")
                    }
                }
                if !verseHits.isEmpty {
                    Section("Verses") {
                        ForEach(verseHits.prefix(30), id: \.key) { hit in
                            Button {
                                if let p = BibleService.parse(hit.key) { go(p.book, p.chapter, p.verse) }
                                dismiss()
                            } label: { ScriptureBlock(ref: hit.key, text: hit.value, size: 16) }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !articleHits.isEmpty {
                    Section("Walking guide") {
                        ForEach(articleHits) { a in NavigationLink(a.title) { ArticleView(article: a) } }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "John 3:16, or a word")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close", systemImage: "xmark") { dismiss() } } }
        }
    }
}
