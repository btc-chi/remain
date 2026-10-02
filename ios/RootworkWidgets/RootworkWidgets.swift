import WidgetKit
import SwiftUI

@main
struct RootworkWidgets: WidgetBundle {
    var body: some Widget {
        RingsWidget()
        VerseWidget()
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetBridge.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // The app reloads timelines whenever a step is done; refresh after midnight so the rings reset.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: WidgetBridge.read())], policy: .after(midnight)))
    }
}

// MARK: - Rings

struct RingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "rings", provider: SnapshotProvider()) { entry in
            RingsWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Rootwork rings")
        .description("Pray, Read, Write. Close all three.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct RingsWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let progress = entry.snapshot.progressForToday
        switch family {
        case .accessoryCircular:
            TrinityRings(progress: progress, lineWidth: 4, showsTriangle: false).padding(2)
                .widgetAccentable()
        default:
            VStack(alignment: .leading, spacing: 6) {
                TrinityRings(progress: progress, lineWidth: 9).frame(maxWidth: .infinity)
                HStack {
                    Label("\(entry.snapshot.streak)", systemImage: "flame.fill").font(.caption.weight(.semibold))
                        .foregroundStyle(Trinity.father.color)
                    Spacer()
                    Text(progress.reduce(0, +) >= 6 ? "Done" : "\(progress.reduce(0, +))/6").font(.caption.weight(.semibold))
                }
            }
        }
    }
}

// MARK: - Verse

struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "verse", provider: SnapshotProvider()) { entry in
            VerseWidgetView(entry: entry).containerBackground(for: .widget) {
                Image("verse").resizable().scaledToFill().overlay(Color.black.opacity(0.35))
            }
        }
        .configurationDisplayName("Verse of the day")
        .description("Today's verse on your Home Screen.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

struct VerseWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let s = entry.snapshot
        if family == .accessoryRectangular {
            VStack(alignment: .leading) {
                Text(s.verseRef).font(.caption.bold())
                Text(s.verseText).font(.system(.caption, design: .serif)).lineLimit(3)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(s.verseRef).font(.caption.weight(.semibold)).opacity(0.85)
                Text(s.verseText).font(.system(size: 18, design: .serif)).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
