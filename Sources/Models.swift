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
    /// Tokens consumed in the most recent session (active OR just expired).
    /// When there are no sessions at all (empty data) this is a zero bucket.
    let session: UsageBucket
    /// Start of the most recent session. `nil` when there are no messages
    /// at all yet on this machine.
    let sessionStart: Date?
    /// End of the most recent session = `sessionStart + 5h`. `nil` when no
    /// messages.
    let sessionResetAt: Date?
    /// `true` when `now` is still within `[sessionStart, sessionResetAt)`,
    /// i.e. the user can still send prompts in this window.
    /// `false` when the most recent session has elapsed (no new prompts have
    /// arrived to start the next one yet).
    let isSessionActive: Bool
    let today: UsageBucket
    let week: UsageBucket
    let month: UsageBucket
    let allTime: UsageBucket
    let lastMessageAt: Date?
    let totalEntries: Int
    let generatedAt: Date
    /// User-configured session token allowance (e.g. Pro / Max 5x / Max 20x).
    /// `nil` means "don't display a limit, just the raw count".
    let sessionTokenLimit: Int?
}

/// User-selectable plan presets. Numbers are conservative estimates of the
/// rough per-5h-session token allowance — Anthropic does not publish hard
/// caps, so these are "good enough for a progress bar", not contractual.
enum SessionPlan: String, CaseIterable {
    case pro    = "pro"
    case max5x  = "max5x"
    case max20x = "max20x"
    case hidden = "hidden"

    var tokenLimit: Int? {
        switch self {
        case .pro:    return   250_000
        case .max5x:  return 1_000_000
        case .max20x: return 5_000_000
        case .hidden: return nil
        }
    }

    var displayName: String {
        switch self {
        case .pro:    return "Pro (~250k / Session)"
        case .max5x:  return "Max 5× (~1M / Session)"
        case .max20x: return "Max 20× (~5M / Session)"
        case .hidden: return "Limit ausblenden"
        }
    }
}
