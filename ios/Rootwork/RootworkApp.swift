import SwiftUI
import SwiftData

@main
struct RootworkApp: App {
    @State private var gate = GateService()
    @State private var bible = BibleService()
    @State private var reader = ScriptureReader()
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(gate)
                .environment(bible)
                .environment(reader)
                .environment(library)
        }
        .modelContainer(for: [Entry.self, DayRecord.self, SwordVerse.self, Mark.self, Person.self]) { result in
            if case .success(let container) = result {
                SeedData.seedIfNeeded(container.mainContext)
            }
        }
    }
}
