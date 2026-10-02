import SwiftUI
import SwiftData

/// Today · Bible · Pray · Journal · Sword. "You" lives in Today's toolbar.
struct RootTabView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @Environment(Library.self) private var library
    @Environment(GateService.self) private var gate
    @AppStorage("onboarded") private var onboarded = false
    @State private var tab: AppTab = .today
    @State private var nav = AppNavigation()

    enum AppTab: Hashable { case today, bible, pray, journal, sword }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.max", value: .today) { TodayView() }
            Tab("Bible", systemImage: "book.closed", value: .bible) { BibleView() }
            Tab("Pray", systemImage: "hands.and.sparkles", value: .pray) { PrayView() }
            Tab("Journal", systemImage: "bubble.left", value: .journal) { JournalView() }
            Tab("Sword", systemImage: "shield.lefthalf.filled", value: .sword) { SwordView() }
        }
        .tint(Trinity.son.color)
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(nav)
        .onChange(of: nav.tab) { _, t in if let t { tab = t; nav.tab = nil } }
        .fullScreenCover(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) { OnboardingView() }
        .onChange(of: phase, initial: true) { _, p in
            guard p == .active else { return }
            DaySync.refresh(ctx, library: library, gate: gate)
            Reminders.reschedule(library: library)
        }
    }
}

/// Cross-tab navigation: any screen can send you to another tab, chapter, or moment.
@MainActor @Observable final class AppNavigation {
    var tab: RootTabView.AppTab?
    /// Bible location requested by another screen.
    var open: BibleLocation?

    func go(_ t: RootTabView.AppTab) { tab = t }
    func read(_ book: String, _ chapter: Int) { open = BibleLocation(book: book, chapter: chapter); tab = .bible }
}

struct BibleLocation: Hashable {
    let book: String
    let chapter: Int
}
