import SwiftUI
import SwiftData
import FamilyControls

/// Today: the verse over art, the three rings with one button, then the day's reading and your own words.
struct TodayView: View {
    @Environment(AppNavigation.self) private var nav
    @Environment(GateService.self) private var gate
    @Environment(Library.self) private var library
    @Query(sort: \DayRecord.day, order: .reverse) private var days: [DayRecord]
    @Query(sort: \Entry.createdAt) private var entries: [Entry]
    @AppStorage("plan.book") private var planBook = "Luke"
    @AppStorage("plan.chapter") private var planChapter = 10
    @State private var showRootwork = false
    @State private var showProfile = false
    @State private var showPicker = false
    @State private var praying: PrayerScript?

    private var today: DayRecord? { days.first { Calendar.current.isDateInToday($0.day) } }
    private var ringProgress: [Int] { today?.ringProgress ?? [0, 0, 0] }
    private var isComplete: Bool { today?.isComplete == true }
    private var streak: Streak.Result { Streak.compute(completedDays: Set(days.filter(\.isComplete).map(\.day))) }

    /// The Remembrancer: one of your own words, matched to what you've been carrying lately.
    private var resurfaced: Entry? {
        let recent = Set(entries.suffix(5).flatMap(\.tags))
        let pool = entries.filter { $0.kind != .confession && !Set($0.tags).isDisjoint(with: recent) }
        let source = pool.isEmpty ? entries.filter { $0.kind == .prayer } : pool
        guard !source.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return source[day % source.count]
    }

    var body: some View {
        let votd = library.verseOfTheDay()
        let memory = library.memoryVerse()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VerseOfTheDayCard(verse: votd) {
                        praying = .verse(ref: votd.ref, text: votd.text)
                    }
                    SectionHeader(title: "Rootwork", trailing: isComplete ? "Done" : "~20 min")
                    ringsCard
                    SectionHeader(title: "Today")
                    todayList
                    if let r = resurfaced {
                        SectionHeader(title: "From your own hand")
                        Card {
                            Text("\(r.kind.label) · \(r.createdAt.formatted(.dateTime.month(.wide)))")
                                .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            Text(r.text).font(Fonts.word(19)).lineLimit(8)
                            HStack {
                                Button("Read all") { nav.go(.journal) }
                                ShareLink(item: r.text) { Text("Send") }
                            }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.primary)
                        }
                    }
                    SectionHeader(title: "Memory verse", trailing: "This week")
                    Card {
                        ScriptureBlock(ref: memory.ref, text: memory.text)
                        Button("Practice") { nav.go(.sword) }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .groupedBackground()
            .navigationTitle(isComplete ? "Remain in him" : greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("\(streak.days)", systemImage: "flame.fill")
                        .labelStyle(.titleAndIcon).font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Trinity.father.color)
                        .accessibilityLabel("\(streak.days) day streak")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("You", systemImage: "person.crop.circle") { showProfile = true }
                }
            }
            .fullScreenCover(isPresented: $showRootwork) { RootworkFlowView() }
            .fullScreenCover(item: $praying) { PrayerSessionView(script: $0) }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .familyActivityPicker(isPresented: $showPicker, selection: Bindable(gate).selection)
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
    }

    private var ringsCard: some View {
        Card {
            HStack(spacing: 18) {
                TrinityRings(progress: ringProgress).frame(width: 150)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Trinity.allCases) { t in
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(t.act) · \(t.person)").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            (Text("\(ringProgress[t.rawValue])").foregroundStyle(t.color)
                             + Text("/\(t.goal)").font(.subheadline).foregroundStyle(.secondary))
                                .font(.title2.weight(.semibold)).monospacedDigit()
                        }
                    }
                }
            }
            Button { showRootwork = true } label: {
                Label(isComplete ? "Review today" : ringProgress.reduce(0, +) == 0 ? "Begin" : "Continue", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent).tint(Color(.label))
            Text(nextHint).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    private var nextHint: String {
        let done = Set(today?.steps ?? [])
        guard let next = RootworkStep.allCases.first(where: { !done.contains($0) }) else {
            return "Rings closed. Your apps are open."
        }
        return next == .pray ? "First: pray. “Open my eyes, that I may see wondrous things out of your law.”"
                             : "Next: \(next.title.lowercased())"
    }

    private var todayList: some View {
        let day = Calendar.current.component(.day, from: .now)
        return VStack(spacing: 0) {
            ListRow(art: "son", title: "\(planBook) \(planChapter)", subtitle: "Today's chapter") { nav.read(planBook, planChapter) }
            Divider().padding(.leading, 82)
            ListRow(art: "father", title: "Proverbs \(day)", subtitle: "One Proverb for each day of the month") { nav.read("Proverbs", day) }
            Divider().padding(.leading, 82)
            ListRow(symbol: "moon.fill", color: .indigo, title: "Night watch",
                    subtitle: today?.nightWatchAt != nil ? "Done tonight" : "Thank, confess, lay it down") { nav.go(.pray) }
            Divider().padding(.leading, 82)
            ListRow(symbol: gate.isOpen ? "lock.open.fill" : "lock.fill", color: .gray,
                    title: gate.restingCount == 0 ? "Rest your apps" : gate.isOpen ? "Apps open" : "\(gate.restingCount) apps resting",
                    subtitle: gate.restingCount == 0 ? "Choose apps that wait for your rings" : gate.isOpen ? "Rootwork done for today" : "They open when your rings close") {
                if gate.isAuthorized { showPicker = true } else { Task { await gate.authorize(); showPicker = true } }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }
}

/// Full-bleed art with the verse in New York, and glass actions floating on top.
struct VerseOfTheDayCard: View {
    let verse: Library.DailyVerse
    var onPray: () -> Void
    @Environment(\.modelContext) private var ctx
    @Query private var swords: [SwordVerse]

    var body: some View {
        let kept = swords.contains { $0.ref == verse.ref }
        ZStack(alignment: .bottom) {
            ArtBackground(art: verse.art)
            VStack(alignment: .leading, spacing: 0) {
                Text("Verse of the Day").font(.footnote.weight(.semibold)).opacity(0.9)
                Text(verse.ref).font(.title3.bold())
                Spacer(minLength: 20)
                Text(verse.text).font(Fonts.word(verse.text.count > 120 ? 23 : 30))
                    .shadow(color: .black.opacity(0.3), radius: 10)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 18)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            if !kept { ctx.insert(SwordVerse(ref: verse.ref, text: verse.text)) }
                        } label: { Label(kept ? "Kept" : "Keep", systemImage: kept ? "heart.fill" : "heart").frame(maxWidth: .infinity) }
                        Button(action: onPray) { Label("Pray this", systemImage: "hands.and.sparkles").frame(maxWidth: .infinity) }
                        ShareLink(item: "\(verse.text) \(verse.ref)") { Image(systemName: "square.and.arrow.up") }
                    }
                    .buttonStyle(.glass).controlSize(.large)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(height: 440)
        .clipShape(.rect(cornerRadius: 24))
    }
}

struct ListRow: View {
    var art: String? = nil
    var symbol: String? = nil
    var color: Color = .gray
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let art {
                    Image(art).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(.rect(cornerRadius: 12))
                } else if let symbol {
                    Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(.white)
                        .frame(width: 34, height: 34).background(color, in: .rect(cornerRadius: 9))
                        .frame(width: 52)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
