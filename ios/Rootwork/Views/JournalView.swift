import SwiftUI
import SwiftData

/// Your prayer book as a Messages thread: everything you've written, in one place, in order.
struct JournalView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Library.self) private var library
    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @State private var filter: Entry.Kind?
    @State private var search = ""
    @State private var kind: Entry.Kind = .prayer
    @State private var tag: String?
    @State private var draft = ""
    @State private var sharing: Entry?
    @State private var praying: PrayerScript?
    @FocusState private var composing: Bool

    private var shown: [Entry] {
        entries.filter { e in
            (filter == nil || e.kind == filter) &&
            (search.isEmpty || e.text.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .trailing, spacing: 4) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { i, e in
                            if i == 0 || !Calendar.current.isDate(e.createdAt, equalTo: shown[i - 1].createdAt, toGranularity: .day) {
                                Text(dateLabel(e.createdAt))
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).padding(.top, 16).padding(.bottom, 4)
                            }
                            Bubble(entry: e, momentName: e.tags.first.flatMap { library.moment(tag: $0)?.name })
                                .id(e.id)
                                .contextMenu { menu(e) }
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 12)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: entries.count) {
                    if let last = shown.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                .overlay {
                    if shown.isEmpty {
                        ContentUnavailableView(search.isEmpty ? "Nothing here yet" : "No matches", systemImage: "bubble.left",
                                               description: Text("Write a prayer below. It stays here so you can come back to it."))
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search your words")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Filter", systemImage: filter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill") {
                        Picker("Show", selection: $filter) {
                            Label("Everything", systemImage: "tray").tag(Entry.Kind?.none)
                            ForEach(Entry.Kind.allCases) { Label($0.label, systemImage: $0.symbol).tag(Optional($0)) }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .sheet(item: $sharing) { ShareCardSheet(entry: $0) }
            .fullScreenCover(item: $praying) { PrayerSessionView(script: $0) }
        }
    }

    @ViewBuilder private func menu(_ e: Entry) -> some View {
        if e.kind != .confession {
            Button("Share as card", systemImage: "photo") { sharing = e }
            ShareLink(item: e.text) { Label("Share text", systemImage: "square.and.arrow.up") }
        }
        Button("Pray this again", systemImage: "hands.and.sparkles") { praying = .own(e) }
        Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = e.text }
        Menu("Moment", systemImage: "tag") {
            ForEach(library.moments) { m in
                Button(m.name, systemImage: e.tags.contains(m.tag) ? "checkmark" : m.symbol) {
                    if e.tags.contains(m.tag) { e.tags.removeAll { $0 == m.tag } } else { e.tags.append(m.tag) }
                }
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { ctx.delete(e) }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Entry.Kind.allCases) { k in
                        Button { kind = k } label: {
                            Label(k.label, systemImage: k.symbol).font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(kind == k ? Color(.label) : Color(.tertiarySystemFill), in: .capsule)
                                .foregroundStyle(kind == k ? Color(.systemBackground) : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                    Menu {
                        Button("None") { tag = nil }
                        ForEach(library.moments) { m in Button(m.name, systemImage: m.symbol) { tag = m.tag } }
                    } label: {
                        Label(tag.flatMap { library.moment(tag: $0)?.name } ?? "Moment", systemImage: "tag")
                            .font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                    }
                }
                .padding(.horizontal, 4)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(kind.placeholder, text: $draft, axis: .vertical)
                    .font(Fonts.word(17)).lineLimit(1...8)
                    .focused($composing)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color(.systemBackground).opacity(0.6), in: .rect(cornerRadius: 20))
                Button { send() } label: { Image(systemName: "arrow.up").font(.headline).frame(width: 30, height: 30) }
                    .buttonStyle(.glassProminent).buttonBorderShape(.circle)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 10).padding(.bottom, 6)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        ctx.insert(Entry(kind, text, tags: tag.map { [$0] } ?? []))
        try? ctx.save()
        draft = ""; tag = nil
    }

    private func dateLabel(_ d: Date) -> String {
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
        return d.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private struct Bubble: View {
    let entry: Entry
    let momentName: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(entry.text)
                .font(Fonts.word(17)).italic(entry.kind == .verse)
                .foregroundStyle(ink)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(fill, in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20))
            HStack(spacing: 4) {
                Image(systemName: entry.kind.symbol)
                Text(receipt)
            }
            .font(.caption2).foregroundStyle(.secondary).padding(.trailing, 6)
        }
        .frame(maxWidth: 310, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var receipt: String {
        var parts = [entry.kind.label]
        if let momentName { parts.append(momentName) }
        if entry.kind == .confession { parts.append("Brought to him · 1 John 1:9") }
        if !entry.sharedWith.isEmpty { parts.append("Shared with \(entry.sharedWith.joined(separator: ", "))") }
        if let ref = entry.verseRef { parts.append("Prayed back \(ref)") }
        return parts.joined(separator: " · ")
    }

    private var fill: AnyShapeStyle {
        switch entry.kind {
        case .prayer: AnyShapeStyle(Trinity.son.color.gradient)
        case .reflection: AnyShapeStyle(Color(.secondarySystemFill))
        case .verse: AnyShapeStyle(Trinity.spirit.color.opacity(0.2))
        case .confession: AnyShapeStyle(Color(.label).opacity(0.85))
        case .vow: AnyShapeStyle(Trinity.father.color.opacity(0.25))
        }
    }

    private var ink: Color {
        switch entry.kind {
        case .prayer: .white
        case .confession: Color(.systemBackground)
        default: .primary
        }
    }
}

/// A prayer set as an image card, ready for Messages. Replaces "screenshot the Slack DM".
struct ShareCardSheet: View {
    let entry: Entry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var scale
    @Query(filter: #Predicate<Person> { $0.isBrother }) private var brothers: [Person]
    @State private var art = "father"

    var body: some View {
        let image = render()
        NavigationStack {
            VStack(spacing: 20) {
                PrayerCard(text: entry.text, date: entry.createdAt, art: art)
                    .frame(width: 320, height: 400)
                    .clipShape(.rect(cornerRadius: 24))
                    .shadow(radius: 20, y: 10)
                Picker("Background", selection: $art) {
                    Text("Light").tag("father"); Text("Dusk").tag("verse"); Text("Icon").tag("spirit"); Text("Plain").tag("")
                }
                .pickerStyle(.segmented)
                if let image {
                    ShareLink(item: image, preview: SharePreview("Prayer", image: image)) {
                        Label(brothers.isEmpty ? "Send" : "Send to \(brothers.map(\.name).joined(separator: ", "))",
                              systemImage: "paperplane.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .simultaneousGesture(TapGesture().onEnded {
                        let names = brothers.map(\.name)
                        entry.sharedWith = Array(Set(entry.sharedWith + (names.isEmpty ? ["a friend"] : names)))
                    })
                }
            }
            .padding(20)
            .navigationTitle("Share prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    @MainActor private func render() -> Image? {
        let r = ImageRenderer(content: PrayerCard(text: entry.text, date: entry.createdAt, art: art).frame(width: 1080 / 3, height: 1350 / 3))
        r.scale = 3
        return r.uiImage.map { Image(uiImage: $0) }
    }
}

struct PrayerCard: View {
    let text: String
    let date: Date
    let art: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if art.isEmpty { Color(red: 0.98, green: 0.97, blue: 0.95) } else { ArtBackground(art: art) }
            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 0)
                Text(text).font(Fonts.word(text.count > 300 ? 15 : 20)).minimumScaleFactor(0.6)
                Text(date.formatted(.dateTime.month(.wide).day().year())).font(.caption.weight(.semibold)).opacity(0.75)
            }
            .foregroundStyle(art.isEmpty ? .black : .white)
            .padding(24)
        }
    }
}
