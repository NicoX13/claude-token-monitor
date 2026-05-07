import Foundation

struct UsageEntry {
    let timestamp: Date
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let messageId: String
    let requestId: String?
    let sessionId: String

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }
}

struct UsageBucket {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cost: Double = 0
    var messageCount: Int = 0
    var perModel: [String: UsageBucket] = [:]

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    mutating func add(_ e: UsageEntry, cost: Double) {
        inputTokens += e.inputTokens
        outputTokens += e.outputTokens
        cacheCreationTokens += e.cacheCreationTokens
        cacheReadTokens += e.cacheReadTokens
        self.cost += cost
        messageCount += 1
        var sub = perModel[e.model] ?? UsageBucket()
        sub.inputTokens += e.inputTokens
        sub.outputTokens += e.outputTokens
        sub.cacheCreationTokens += e.cacheCreationTokens
        sub.cacheReadTokens += e.cacheReadTokens
        sub.cost += cost
        sub.messageCount += 1
        perModel[e.model] = sub
    }
}

struct UsageReport {
    let session: UsageBucket
    let sessionStart: Date?
    let sessionResetAt: Date?
    let today: UsageBucket
    let week: UsageBucket
    let month: UsageBucket
    let allTime: UsageBucket
    let lastMessageAt: Date?
    let totalEntries: Int
    let generatedAt: Date
}
