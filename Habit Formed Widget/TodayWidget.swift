import SwiftUI
import WidgetKit

/// The Home Screen widget: today's count and streak (small), plus the week
/// and a tap to log the habits still open (medium).
struct TodayWidget: Widget {
    let kind = "TodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's habits and your streak. Tap a habit to log it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    /// Nil when the app has not written a snapshot for this day yet.
    let page: WidgetSnapshot.Page?
}

/// Reads the snapshot the app wrote. Each timeline holds now and the coming
/// midnight, when the snapshot's tomorrow page takes over.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), page: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(TodayEntry(date: Date(), page: .sample))
        } else {
            completion(entry(at: Date(), from: WidgetStore.loadSnapshot()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetStore.loadSnapshot()
        let calendar = Calendar.current
        var entries = [entry(at: now, from: snapshot)]
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            entries.append(entry(at: midnight, from: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, from snapshot: WidgetSnapshot?) -> TodayEntry {
        TodayEntry(date: date, page: snapshot?.page(on: date))
    }
}

// MARK: - Sample

extension WidgetSnapshot.Page {
    /// A plausible day for the gallery and placeholders.
    static var sample: WidgetSnapshot.Page {
        let today = Calendar.current.startOfDay(for: Date())
        let week = (0..<7).map { offset -> WidgetSnapshot.Day in
            let date = Calendar.current.date(byAdding: .day, value: offset - 6, to: today) ?? today
            return WidgetSnapshot.Day(date: date, done: offset == 6 ? 4 : (offset == 1 ? 4 : 6), expected: 6)
        }
        let items = [
            WidgetSnapshot.Item(id: UUID(), title: "Water plant", symbol: "leaf.fill", colorHex: "#739F80", isDone: false, isExpected: true, canLog: true),
            WidgetSnapshot.Item(id: UUID(), title: "Read", symbol: "book.fill", colorHex: "#5966A6", isDone: false, isExpected: true, canLog: true),
            WidgetSnapshot.Item(id: UUID(), title: "Piano", symbol: "pianokeys", colorHex: "#8C5C84", isDone: true, isExpected: true, canLog: true),
        ]
        return WidgetSnapshot.Page(day: today, done: 4, expected: 6, perfectStreak: 5, week: week, items: items)
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry(date: Date(), page: .sample)
}
