import SwiftUI
import SwiftData
import FamilyControls

/// You: streak calendar, rank, badges, your three, and settings.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GateService.self) private var gate
    @Environment(Library.self) private var library
    @Query(sort: \DayRecord.day) private var days: [DayRecord]
    @Query private var entries: [Entry]
    @Query private var swords: [SwordVerse]
    @Query(filter: #Predicate<Person> { $0.isBrother }) private var brothers: [Person]
    @AppStorage(Reminders.morningKey) private var morning = Reminders.defaultTime(6)
    @AppStorage(Reminders.eveningKey) private var evening = Reminders.defaultTime(18, 30)
    @AppStorage(Reminders.nightKey) private var night = Reminders.defaultTime(21, 30)
    @State private var showPicker = false
    @State private var editingPerson: Person?
    @State private var addingBrother = false

    var body: some View {
        let fruit = Fruit.total(days: days, entries: entries, swords: swords)
        let rank = Rank.of(fruit: fruit)
        let completed = Set(days.filter(\.isComplete).map(\.day))
        let streak = Streak.compute(completedDays: completed)
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(rank.title).font(Fonts.word(36, weight: .semibold))
                            Spacer()
                            Label("\(streak.days)", systemImage: "flame.fill").font(.title3.weight(.semibold))
                                .foregroundStyle(Trinity.father.color).monospacedDigit()
                        }
                        Text(rank.verse).font(.subheadline).foregroundStyle(.secondary)
                        if let next = rank.next {
                            ProgressView(value: Double(fruit - rank.threshold), total: Double(next.threshold - rank.threshold))
                                .tint(Trinity.father.color)
                            Text("\(fruit) fruit · \(next.threshold - fruit) to \(next.title)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    MonthCalendar(completed: completed, mercy: Set(streak.mercyDays))
                } header: { Text(Date.now.formatted(.dateTime.month(.wide).year())) } footer: {
                    Text("✦ marks a mercy day: you missed one and came back the next morning, so the streak held. Lamentations 3:22–23")
                }

                Section("Badges") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(Badge.all(days: days, entries: entries, swords: swords, streak: streak.days)) { b in
                            VStack(spacing: 6) {
                                Image(systemName: b.symbol).font(.title2)
                                    .frame(width: 54, height: 54)
                                    .background(b.earned ? Trinity.father.color.opacity(0.25) : Color(.tertiarySystemFill), in: .circle)
                                    .foregroundStyle(b.earned ? Trinity.father.color : .secondary)
                                Text(b.name).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                            }
                            .opacity(b.earned ? 1 : 0.5)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    ForEach(brothers) { p in
                        Button { editingPerson = p } label: {
                            HStack { Avatar(name: p.name, size: 36); Text(p.name); Spacer(); Text(p.relation).foregroundStyle(.secondary) }
                        }
                        .buttonStyle(.plain)
                    }
                    if brothers.count < 3 {
                        Button("Add one of your three", systemImage: "person.badge.plus") { addingBrother = true }
                    }
                } header: { Text("Your three") } footer: {
                    Text("The people you share prayers with. Brothers who walk with you, two by two (Luke 10:1).")
                }

                Section("The ranks") {
                    ForEach(Rank.allCases, id: \.self) { r in
                        HStack {
                            Image(systemName: fruit >= r.threshold ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(fruit >= r.threshold ? Trinity.father.color : Color(.tertiaryLabel))
                            Text(r.title).fontWeight(r == rank ? .semibold : .regular)
                            Spacer()
                            Text("\(r.threshold)").foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    LabeledContent("Rootwork", value: "+\(Fruit.rootwork)")
                    LabeledContent("Night watch", value: "+\(Fruit.nightWatch)")
                    LabeledContent("Share a prayer", value: "+\(Fruit.sharedPrayer)")
                    LabeledContent("Memorize a verse", value: "+\(Fruit.verseMemorized)")
                }

                Section {
                    Button(gate.isAuthorized ? "Choose apps (\(gate.restingCount))" : "Turn on app rest", systemImage: "lock") {
                        if gate.isAuthorized { showPicker = true } else { Task { await gate.authorize(); showPicker = true } }
                    }
                    LabeledContent("Emergency opens left this week", value: "\(gate.emergencyUnlocksLeft)")
                } header: { Text("App rest") } footer: {
                    Text("Chosen apps rest each morning at 4 AM and open when your rings close.")
                }

                Section("Reminders") {
                    timePicker("Morning verse", $morning)
                    timePicker("Evening nudge", $evening)
                    timePicker("Night watch", $night)
                }

                Section("About") {
                    LabeledContent("Bible text", value: "World English Bible")
                    LabeledContent("Art", value: "Public-domain masterworks")
                    Text("Church, Bierstadt, Bloch, Rublev. Landscapes for the verse of the day will be added.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .familyActivityPicker(isPresented: $showPicker, selection: Bindable(gate).selection)
            .sheet(item: $editingPerson) { PersonEditor(person: $0) }
            .sheet(isPresented: $addingBrother) { PersonEditor(person: nil) }
            .onChange(of: [morning, evening, night]) { Reminders.reschedule(library: library) }
        }
    }

    private func timePicker(_ title: String, _ value: Binding<Double>) -> some View {
        DatePicker(title, selection: Binding(get: { Date(timeIntervalSinceReferenceDate: value.wrappedValue) },
                                             set: { value.wrappedValue = $0.timeIntervalSinceReferenceDate }),
                   displayedComponents: .hourAndMinute)
    }
}

/// This month, one dot per day: filled when Rootwork was done.
struct MonthCalendar: View {
    let completed: Set<Date>
    let mercy: Set<Date>

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now))!
        let count = cal.range(of: .day, in: .month, for: .now)!.count
        let lead = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                Text(s).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 32) }
            ForEach(0..<count, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: start)!
                let done = completed.contains(day)
                let isMercy = mercy.contains(day)
                let isToday = cal.isDateInToday(day)
                ZStack {
                    Circle().fill(done ? Trinity.father.color : Color.clear)
                    if isToday && !done { Circle().stroke(Trinity.son.color, lineWidth: 2) }
                    Text(isMercy ? "✦" : "\(i + 1)").font(.footnote.weight(done ? .bold : .regular))
                        .foregroundStyle(done ? .white : isMercy ? Trinity.father.color : day > .now ? .secondary : .primary)
                }
                .frame(height: 32)
            }
        }
        .padding(.vertical, 6)
    }
}

struct Badge: Identifiable {
    let name: String
    let symbol: String
    let earned: Bool
    var id: String { name }

    static func all(days: [DayRecord], entries: [Entry], swords: [SwordVerse], streak: Int) -> [Badge] {
        let done = days.filter(\.isComplete).count
        return [
            Badge(name: "First fruit", symbol: "leaf.fill", earned: done >= 1),
            Badge(name: "Sower", symbol: "laurel.leading", earned: done >= 7),
            Badge(name: "Two by two", symbol: "person.2.fill", earned: entries.contains { !$0.sharedWith.isEmpty }),
            Badge(name: "Swordsmith", symbol: "shield.lefthalf.filled", earned: swords.count >= 10),
            Badge(name: "Hidden word", symbol: "heart.text.square.fill", earned: swords.contains { $0.memorizedAt != nil }),
            Badge(name: "Night watch", symbol: "moon.stars.fill", earned: days.contains { $0.nightWatchAt != nil }),
            Badge(name: "Thirty days", symbol: "flame.fill", earned: streak >= 30),
            Badge(name: "Full armor", symbol: "checkmark.shield.fill", earned: done >= 40),
            Badge(name: "Finished Luke", symbol: "book.closed.fill",
                  earned: days.contains { $0.chapterRef == "Luke 24" && $0.isComplete }),
        ]
    }
}
