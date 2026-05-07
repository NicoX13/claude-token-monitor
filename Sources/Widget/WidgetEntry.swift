import WidgetKit
import Foundation

struct ClaudeUsageEntry: TimelineEntry {
    let date: Date
    let sessionTokens: Int
    let sessionCost: Double
    let sessionResetAt: Date?
    let sessionStart: Date?
    let todayTokens: Int
    let todayCost: Double
    let weekTokens: Int
    let weekCost: Double
    let monthTokens: Int
    let monthCost: Double
    let allTimeTokens: Int
    let lastActivity: Date?

    static let placeholder = ClaudeUsageEntry(
        date: Date(),
        sessionTokens: 0,
        sessionCost: 0,
        sessionResetAt: nil,
        sessionStart: nil,
        todayTokens: 0,
        todayCost: 0,
        weekTokens: 0,
        weekCost: 0,
        monthTokens: 0,
        monthCost: 0,
        allTimeTokens: 0,
        lastActivity: nil
    )
}
