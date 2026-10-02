import SwiftUI
import SwiftData

/// Pray: Morning (open your eyes), People (the ones you carry), Night (thank, confess, lay it down).
struct PrayView: View {
    enum Part: String, CaseIterable, Identifiable { case morning = "Morning", people = "People", night = "Night"; var id: Self { self } }

    @State private var part: Part = Calendar.current.component(.hour, from: .now) >= 18 ? .night : .morning

    var body: some View {
        NavigationStack {
            Group {
                switch part {
                case .morning: MorningPrayers()
                case .people: PeoplePrayers()
                case .night: NightWatchView()
                }
            }
            .groupedBackground()
            .navigationTitle("Pray")
            .safeAreaInset(edge: .top) {
                Picker("Part", selection: $part) { ForEach(Part.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Prayer scripts

/// A prayer to pray one line at a time.
struct PrayerScript: Identifiable {
    struct Line { var text: String; var note: String? = nil }

    let id = UUID()
    var title: String
    var source: String
    var lines: [Line]
    var art = "father"
    /// Counts as the first Rootwork step ("Pray first") when prayed before anything else today.
    var countsAsPrayFirst = true
    var person: Person? = nil

    static func verse(ref: String, text: String) -> PrayerScript {
        PrayerScript(title: "Pray this verse", source: ref,
                     lines: [Line(text: "Father,")] + sentences(text).map { Line(text: $0) }
                        + [Line(text: "Let this be true in me today."), Line(text: "In Jesus' name. Amen.")])
    }

    static func opener(_ text: String, source: String) -> PrayerScript {
        PrayerScript(title: "Morning", source: source, lines: sentences(text).map { Line(text: $0) } + [Line(text: "Amen.")])
    }

    static func own(_ e: Entry) -> PrayerScript {
        PrayerScript(title: "Your words", source: e.createdAt.formatted(.dateTime.month(.wide).day().year()),
                     lines: e.text.split(separator: "\n", omittingEmptySubsequences: true).map { Line(text: String($0)) })
    }

    @MainActor static func lordsPrayer(_ library: Library) -> PrayerScript {
        let rows = library.guide.first { $0.id == "pray" }?.blocks.first { $0.type == "rows" }?.rows ?? []
        return PrayerScript(title: "The Lord's Prayer, slowly", source: "Matthew 6:9-13",
                            lines: rows.map { Line(text: $0.label, note: $0.text) } + [Line(text: "Amen.")])
    }

    static func person(_ p: Person) -> PrayerScript {
        var lines = [Line(text: "Father, I lift up \(p.name) to you.", note: p.relation.isEmpty ? nil : p.relation)]
        lines += p.requests.split(separator: "\n").map { Line(text: String($0)) }
        lines += [Line(text: "Bless \(p.name) today. Draw near to them, and let them know you are near."),
                  Line(text: "Use me to love them well."), Line(text: "In Jesus' name. Amen.")]
        return PrayerScript(title: "Praying for \(p.name)", source: "", lines: lines, art: "son", countsAsPrayFirst: false, person: p)
    }

    private static func sentences(_ s: String) -> [String] {
        var out: [String] = []
        s.enumerateSubstrings(in: s.startIndex..., options: .bySentences) { sub, _, _, _ in
            if let t = sub?.trimmingCharacters(in: .whitespaces), !t.isEmpty { out.append(t) }
        }
        return out.isEmpty ? [s] : out
    }
}

/// Full-screen, one line at a time, over art. Tap to continue; Amen at the end.
struct PrayerSessionView: View {
    let script: PrayerScript
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(Library.self) private var library
    @Environment(GateService.self) private var gate
    @Environment(ScriptureReader.self) private var reader
    @State private var index = 0
    @State private var finished = false
    @AppStorage("prayer.readAloud") private var readAloud = false

    var body: some View {
        let last = index >= script.lines.count - 1
        ZStack {
            ArtBackground(art: script.art).ignoresSafeArea()
            Color.black.opacity(0.25).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                if finished {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 54)).symbolEffect(.bounce, value: finished)
                    Text("Amen").font(Fonts.word(40, weight: .semibold))
                } else {
                    let line = script.lines[index]
                    Text(line.text).font(Fonts.word(line.text.count > 90 ? 26 : 32))
                        .multilineTextAlignment(.center)
                        .id(index)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
                    if let note = line.note {
                        Text(note).font(.callout).multilineTextAlignment(.center).opacity(0.8).id("n\(index)")
                    }
                }
                Spacer()
                if !finished {
                    HStack(spacing: 6) {
                        ForEach(script.lines.indices, id: \.self) { i in
                            Capsule().fill(.white.opacity(i <= index ? 0.9 : 0.3)).frame(width: i == index ? 18 : 6, height: 6)
                        }
                    }
                    Button { advance() } label: {
                        Text(last ? "Amen" : "Continue").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.glassProminent).tint(last ? Trinity.father.color : .white.opacity(0.25))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28).padding(.bottom, 20)
            .contentShape(.rect)
            .onTapGesture { if !finished { advance() } }
        }
        .overlay(alignment: .top) {
            HStack {
                Button { reader.stop(); dismiss() } label: { Image(systemName: "xmark").font(.headline).frame(width: 36, height: 36) }
                    .buttonStyle(.glass).buttonBorderShape(.circle)
                Spacer()
                VStack(spacing: 2) {
                    Text(script.title).font(.subheadline.weight(.semibold))
                    if !script.source.isEmpty { Text(script.source).font(.caption).opacity(0.8) }
                }
                Spacer()
                Button { readAloud.toggle(); if readAloud { speak() } else { reader.stop() } } label: {
                    Image(systemName: readAloud ? "speaker.wave.2.fill" : "speaker.slash").font(.headline).frame(width: 36, height: 36)
                }
                .buttonStyle(.glass).buttonBorderShape(.circle)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
        }
        .animation(.easeInOut(duration: 0.45), value: index)
        .animation(.spring, value: finished)
        .onAppear { if readAloud { speak() } }
        .statusBarHidden()
    }

    private func speak() { reader.speak(script.lines[index].text) }

    private func advance() {
        if index < script.lines.count - 1 {
            index += 1
            if readAloud { speak() }
            return
        }
        finished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let p = script.person { p.lastPrayedAt = .now }
        if script.countsAsPrayFirst { DaySync.mark(.pray, ctx, library: library, gate: gate) }
        try? ctx.save()
        Task { try? await Task.sleep(for: .seconds(1.4)); reader.stop(); dismiss() }
    }
}

// MARK: - Morning

private struct MorningPrayers: View {
    @Environment(Library.self) private var library
    @Query(filter: #Predicate<Entry> { $0.kindRaw == "prayer" }, sort: \Entry.createdAt, order: .reverse) private var mine: [Entry]
    @State private var praying: PrayerScript?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button { praying = .lordsPrayer(library) } label: {
                    ZStack(alignment: .bottomLeading) {
                        ArtBackground(art: "father")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("The Lord's Prayer, slowly").font(.title2.bold())
                            Text("“Lord, teach us to pray.” Luke 11:1").font(Fonts.word(17))
                        }
                        .foregroundStyle(.white).padding(18)
                    }
                    .frame(height: 220).clipShape(.rect(cornerRadius: 24))
                }
                .buttonStyle(.plain)

                SectionHeader(title: "Before you read")
                ForEach(RootworkFlowView.openers.indices, id: \.self) { i in
                    let o = RootworkFlowView.openers[i]
                    prayerRow(o.text, o.source) { praying = .opener(o.text, source: o.source) }
                }

                if !mine.isEmpty {
                    SectionHeader(title: "Your own words")
                    ForEach(mine.prefix(8)) { e in
                        prayerRow(e.text, e.createdAt.formatted(.dateTime.month(.wide).day())) { praying = .own(e) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .fullScreenCover(item: $praying) { PrayerSessionView(script: $0) }
    }

    private func prayerRow(_ text: String, _ source: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Trinity.father.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(text).font(Fonts.word(18)).lineLimit(4).multilineTextAlignment(.leading)
                    Text(source).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - People

private struct PeoplePrayers: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Person.createdAt) private var people: [Person]
    @State private var praying: PrayerScript?
    @State private var editing: Person?
    @State private var adding = false

    var body: some View {
        List {
            Section {
                ForEach(people) { p in
                    Button { praying = .person(p) } label: {
                        HStack(spacing: 14) {
                            Avatar(name: p.name, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(.headline)
                                Text(p.requests.isEmpty ? (p.relation.isEmpty ? "Tap to pray" : p.relation) : p.requests)
                                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: p.prayedToday ? "checkmark.circle.fill" : "circle")
                                .font(.title2).foregroundStyle(p.prayedToday ? Palette.done : Color(.tertiaryLabel))
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { ctx.delete(p) }
                        Button("Edit", systemImage: "pencil") { editing = p }
                    }
                    .contextMenu {
                        ShareLink(item: "I prayed for you today, \(p.name).") { Label("Tell them you prayed", systemImage: "paperplane") }
                    }
                }
            } footer: {
                Text("“Pray for one another.” James 5:16. Swipe to edit.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Add", systemImage: "plus") { adding = true } }
        }
        .fullScreenCover(item: $praying) { PrayerSessionView(script: $0) }
        .sheet(item: $editing) { PersonEditor(person: $0) }
        .sheet(isPresented: $adding) { PersonEditor(person: nil) }
        .overlay {
            if people.isEmpty {
                ContentUnavailableView("Who are you carrying?", systemImage: "person.2",
                                       description: Text("Add the people you pray for."))
            }
        }
    }
}

struct PersonEditor: View {
    let person: Person?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var people: [Person]
    @State private var name = ""
    @State private var relation = ""
    @State private var requests = ""
    @State private var isBrother = false

    var body: some View {
        let brothers = people.filter { $0.isBrother && $0 != person }.count
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Who they are (brother, wife, friend)", text: $relation)
                }
                Section("What you're praying for") {
                    TextField("One request per line", text: $requests, axis: .vertical).lineLimit(3...10)
                }
                Section {
                    Toggle("One of my three", isOn: $isBrother).disabled(brothers >= 3 && !isBrother)
                } footer: {
                    Text("Your three are the people you share prayers with. \(3 - brothers) of 3 open.")
                }
            }
            .navigationTitle(person == nil ? "New person" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let p = person { name = p.name; relation = p.relation; requests = p.requests; isBrother = p.isBrother }
            }
        }
    }

    private func save() {
        let p = person ?? { let n = Person(name: name); ctx.insert(n); return n }()
        p.name = name.trimmingCharacters(in: .whitespaces); p.relation = relation; p.requests = requests; p.isBrother = isBrother
        try? ctx.save()
        dismiss()
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 40
    var body: some View {
        let hue = Double(name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 360) / 360
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hue: hue, saturation: 0.35, brightness: 0.6).gradient, in: .circle)
    }
}

// MARK: - Night

/// Night watch: thank, confess, lay it down. Ephesians 6:18, "pray at all times."
private struct NightWatchView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(Library.self) private var library
    @Query(sort: \DayRecord.day, order: .reverse) private var days: [DayRecord]
    @State private var thanks = ""
    @State private var confession = ""
    @State private var burden = ""
    @FocusState private var focused: Bool

    private var doneTonight: Bool { days.first { Calendar.current.isDateInToday($0.day) }?.nightWatchAt != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if doneTonight {
                    Card {
                        Label("Night watch done", systemImage: "moon.stars.fill").font(.headline).foregroundStyle(.indigo)
                        ScriptureBlock(ref: "Psalm 4:8", text: library.text("Psalm 4:8"), size: 20)
                    }
                }
                stepCard(1, "Thank him", "What was good today? Name it.", text: $thanks, placeholder: "Thank you for…")
                stepCard(2, "Confess", "Bring it into the light. This stays private.", text: $confession, placeholder: "Lord, I confess…",
                         verse: ("1 John 1:9", library.text("1 John 1:9")))
                stepCard(3, "Lay it down", "What are you carrying into sleep?", text: $burden, placeholder: "I give you…",
                         verse: ("Matthew 11:28", library.text("Matthew 11:28")))
                Button { finish() } label: {
                    Label("Amen. Sleep in peace.", systemImage: "moon.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent).tint(.indigo)
                .disabled(thanks.isEmpty && confession.isEmpty && burden.isEmpty)
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func stepCard(_ n: Int, _ title: String, _ prompt: String, text: Binding<String>, placeholder: String,
                          verse: (String, String)? = nil) -> some View {
        Card {
            HStack(spacing: 10) {
                Text("\(n)").font(.footnote.bold()).foregroundStyle(.white).frame(width: 24, height: 24).background(.indigo, in: .circle)
                Text(title).font(.headline)
            }
            Text(prompt).font(.subheadline).foregroundStyle(.secondary)
            TextField(placeholder, text: text, axis: .vertical).font(Fonts.word(18)).lineLimit(2...6).focused($focused)
            if let verse, !verse.1.isEmpty { ScriptureBlock(ref: verse.0, text: verse.1, size: 16) }
        }
    }

    private func finish() {
        focused = false
        if !thanks.isEmpty { ctx.insert(Entry(.prayer, "Father, thank you for " + thanks.lowercasedFirst)) }
        if !confession.isEmpty { ctx.insert(Entry(.confession, confession, tags: ["confess"])) }
        if !burden.isEmpty { ctx.insert(Entry(.prayer, "I lay this down before you:\n" + burden + "\nAmen", tags: ["anxiety"])) }
        DayRecord.today(in: ctx).nightWatchAt = .now
        try? ctx.save()
        thanks = ""; confession = ""; burden = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
