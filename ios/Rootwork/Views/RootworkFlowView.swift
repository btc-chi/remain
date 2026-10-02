import SwiftUI
import SwiftData

/// The six-step daily rhythm, one calm page at a time. The rings at the top fill as you go.
/// 1 Pray first · 2 Read one chapter · 3 Write one verse · 4 About God / about me · 5 One action · 6 Pray it back
struct RootworkFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(BibleService.self) private var bible
    @Environment(ScriptureReader.self) private var reader
    @Environment(GateService.self) private var gate
    @Environment(Library.self) private var library
    @Query private var swords: [SwordVerse]

    @AppStorage("plan.book") private var planBook = "Luke"
    @AppStorage("plan.chapter") private var planChapter = 10

    @State private var record: DayRecord?
    @State private var step = 0
    @State private var opener = 0
    @State private var chapter: Chapter?
    @State private var picked: Verse?
    @State private var loadError: String?

    static let openers: [(text: String, source: String)] = [
        ("Open my eyes, that I may see wondrous things out of your law.", "Psalm 119:18"),
        ("I am thankful before you, living and enduring King, for you have mercifully restored my soul within me. Great is your faithfulness.", "Morning thanks · Lamentations 3:23"),
        ("Remain in me, and I in you. I can't bear fruit by myself. Hold me to the vine today.", "From John 15:4"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if step < 6 {
                        Text("\(RootworkStep.allCases[step].ring.act) · step \(step + 1) of 6")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(RootworkStep.allCases[step].ring.color)
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .animation(.smooth, value: step)
            }
            .scrollDismissesKeyboard(.interactively)
            .groupedBackground()
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { reader.stop(); try? ctx.save(); dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    TrinityRings(progress: record?.ringProgress ?? [0, 0, 0], lineWidth: 4, showsTriangle: false)
                        .frame(width: 34)
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            title("Pray first.", "Before you read a word, ask him to open your eyes. Pray it aloud or in your heart.")
            ForEach(Self.openers.indices, id: \.self) { i in
                Button { opener = i } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: opener == i ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(opener == i ? Trinity.father.color : Color.secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Self.openers[i].text).font(Fonts.word(19))
                            Text(Self.openers[i].source).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
        case 1:
            title("Read \(planBook) \(planChapter).", "One chapter, slowly. Tap the verse that stops you.")
            if let chapter {
                Button(reader.isSpeaking ? "Stop listening" : "Listen", systemImage: reader.isSpeaking ? "pause.fill" : "play.fill") {
                    reader.isSpeaking ? reader.stop() : reader.play(chapter.verses)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
                ChapterText(verses: chapter.verses, selected: picked?.number, speaking: reader.current?.number) { picked = $0 }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
            } else if let loadError {
                ContentUnavailableView("Couldn't load the chapter", systemImage: "wifi.slash", description: Text(loadError))
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(40)
            }
        case 2:
            title("Write one verse that stood out.", "It goes into your Sword and into today's entry.")
            ForEach(chapter?.verses ?? []) { v in
                Button { picked = v } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(v.text).font(Fonts.word(18))
                        Text(v.ref).font(.footnote.weight(.semibold)).foregroundStyle(Trinity.son.color)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(picked == v ? Trinity.spirit.color.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                                in: .rect(cornerRadius: 18))
                    .overlay { if picked == v { RoundedRectangle(cornerRadius: 18).stroke(Trinity.spirit.color, lineWidth: 2) } }
                }
                .buttonStyle(.plain)
            }
        case 3:
            title("What does it show you?", nil)
            pickedCard
            field("About God", "He is…", text: binding(\.aboutGod))
            field("About me", "I am…", text: binding(\.aboutMe))
        case 4:
            title("One action for today.", "“Be doers of the word, and not only hearers.” James 1:22")
            field(nil, "Today I will…", text: binding(\.action))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Sit at his feet 5 min before work", "Be patient in the morning", "Send this verse to Ricky", "Check on someone who is grieving"], id: \.self) { s in
                        Button(s) { record?.action = s }.buttonStyle(.bordered).buttonBorderShape(.capsule).font(.footnote)
                    }
                }
            }
            .scrollClipDisabled()
        case 5:
            title("Pray the verse back to him.", "Drafted from your own words. Make it yours, then pray it.")
            TextEditor(text: binding(\.prayback))
                .font(Fonts.word(19)).scrollContentBackground(.hidden)
                .frame(minHeight: 320).padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        default:
            CompletionView(progress: record?.ringProgress ?? [2, 1, 3], verse: library.verseOfTheDay())
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 && step < 6 {
                Button { step -= 1 } label: { Image(systemName: "chevron.left").frame(width: 30, height: 34) }
                    .buttonStyle(.glass)
            }
            Button { advance() } label: {
                Text(["Amen", "I've read it", "Keep this verse", "Continue", "Commit", "Amen", "Go in peace"][step])
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(step < 6 ? RootworkStep.allCases[step].ring.color : Color(.label))
            .disabled(step == 2 && picked == nil)
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    // MARK: - flow

    private func advance() {
        guard let record else { return }
        if step < 6 { record.mark(RootworkStep.allCases[step]) }
        switch step {
        case 1:
            reader.stop()
            record.chapterRef = "\(planBook) \(planChapter)"
        case 2:
            guard let v = picked else { return }
            record.verseRef = v.ref; record.verseText = v.text
            if !swords.contains(where: { $0.ref == v.ref }) { ctx.insert(SwordVerse(ref: v.ref, text: v.text)) }
        case 4:
            if record.prayback.isEmpty { record.prayback = draftPrayback(record) }
        case 5:
            record.completedAt = .now
            ctx.insert(Entry(.prayer, record.prayback, verseRef: record.verseRef))
            if !record.action.isEmpty { ctx.insert(Entry(.vow, "Today I will " + record.action.lowercasedFirst)) }
            advancePlan()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case 6:
            try? ctx.save(); dismiss(); return
        default: break
        }
        try? ctx.save()
        DaySync.refresh(ctx, library: library, gate: gate)
        step += 1
    }

    private func draftPrayback(_ r: DayRecord) -> String {
        """
        Father,
        \(r.verseText ?? "")

        You are \(r.aboutGod.isEmpty ? "faithful" : r.aboutGod.lowercasedFirst).
        I am \(r.aboutMe.isEmpty ? "yours" : r.aboutMe.lowercasedFirst).
        Today I will \(r.action.isEmpty ? "follow you" : r.action.lowercasedFirst).
        Give me the strength to do it.
        In Jesus' name,
        Amen
        """
    }

    private func advancePlan() {
        let plan = BibleService.plan
        guard let i = plan.firstIndex(where: { $0.book == planBook }) else { return }
        if planChapter < plan[i].chapters { planChapter += 1 }
        else { planBook = plan[(i + 1) % plan.count].book; planChapter = 1 }
    }

    private func load() async {
        let r = DayRecord.today(in: ctx)
        record = r
        step = r.isComplete ? 6 : RootworkStep.allCases.firstIndex { !r.steps.contains($0) } ?? 5
        do { chapter = try await bible.chapter(planBook, planChapter) }
        catch { loadError = error.localizedDescription }
        if let ref = r.verseRef { picked = chapter?.verses.first { $0.ref == ref } }
    }

    // MARK: - pieces

    private func title(_ t: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.largeTitle.bold())
            if let sub { Text(sub).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var pickedCard: some View {
        if let v = picked {
            ScriptureBlock(ref: v.ref, text: v.text, size: 18)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        }
    }

    private func field(_ label: String?, _ prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { Text(label).font(.headline) }
            TextField(prompt, text: text, axis: .vertical)
                .font(Fonts.word(18)).lineLimit(3...8)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        }
    }

    private func binding(_ kp: ReferenceWritableKeyPath<DayRecord, String>) -> Binding<String> {
        Binding(get: { record?[keyPath: kp] ?? "" }, set: { record?[keyPath: kp] = $0 })
    }
}

/// The finish: rings close, the triangle appears, the verse of the day sends you out.
struct CompletionView: View {
    let progress: [Int]
    let verse: Library.DailyVerse
    @State private var shown = [0, 0, 0]

    var body: some View {
        VStack(spacing: 18) {
            TrinityRings(progress: shown, lineWidth: 18).frame(width: 220).padding(.top, 20)
            Text("Remain in him.").font(.largeTitle.bold())
            Text("“\(verse.text)” \(verse.ref)").font(Fonts.word(19)).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Label("Your apps are open. Your prayer is in your Journal.", systemImage: "lock.open")
                .font(.subheadline).padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: .capsule)
        }
        .frame(maxWidth: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            shown = progress
        }
    }
}
