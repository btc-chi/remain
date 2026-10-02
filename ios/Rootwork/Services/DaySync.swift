import Foundation
import SwiftData
import WidgetKit

/// Keeps everything outside the app in step with today's record: widgets, the Gate.
@MainActor enum DaySync {
    static func refresh(_ ctx: ModelContext, library: Library, gate: GateService) {
        let days = (try? ctx.fetch(FetchDescriptor<DayRecord>())) ?? []
        let today = days.first { Calendar.current.isDateInToday($0.day) }
        let streak = Streak.compute(completedDays: Set(days.filter(\.isComplete).map(\.day)))
        let votd = library.verseOfTheDay()

        WidgetBridge.write(WidgetSnapshot(day: .now, progress: today?.ringProgress ?? [0, 0, 0],
                                          streak: streak.days, verseRef: votd.ref, verseText: votd.text))
        WidgetCenter.shared.reloadAllTimelines()

        if today?.isComplete == true { gate.rootworkCompleted() }
    }

    /// Marks a step done on today's record and refreshes everything that depends on it.
    static func mark(_ step: RootworkStep, _ ctx: ModelContext, library: Library, gate: GateService) {
        let today = DayRecord.today(in: ctx)
        today.mark(step)
        try? ctx.save()
        refresh(ctx, library: library, gate: gate)
    }
}
