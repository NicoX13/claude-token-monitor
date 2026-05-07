import WidgetKit
import Foundation

struct ClaudeUsageProvider: TimelineProvider {
    typealias Entry = ClaudeUsageEntry

    private let reader = UsageReader()

    func placeholder(in context: Context) -> ClaudeUsageEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudeUsageEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ClaudeUsageEntry>) -> Void) {
        let entry = buildEntry()
        // Refresh every 5 minutes — token files are append-only and small.
        let nextUpdate = Date().addingTimeInterval(5 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func buildEntry() -> ClaudeUsageEntry {
        let r = reader.generateReport()
        return ClaudeUsageEntry(
            date: Date(),
            sessionTokens: r.session.totalTokens,
            sessionCost: r.session.cost,
            sessionResetAt: r.sessionResetAt,
            sessionStart: r.sessionStart,
            todayTokens: r.today.totalTokens,
            todayCost: r.today.cost,
            weekTokens: r.week.totalTokens,
            weekCost: r.week.cost,
            monthTokens: r.month.totalTokens,
            monthCost: r.month.cost,
            allTimeTokens: r.allTime.totalTokens,
            lastActivity: r.lastMessageAt
        )
    }
}
