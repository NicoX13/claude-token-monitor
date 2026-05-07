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

    // MARK: Weekly limits (mirror claude.ai's "Wöchentliche Limits" panel).
    // The week resets every Monday at 06:00 local time. We track three
    // buckets so the UI can show the same breakdown the dashboard uses:
    //   - all models  ("Alle Modelle")
    //   - Sonnet only ("Nur Sonnet")
    //   - Opus / Claude Design ("Claude Design")
    /// All assistant messages since the previous Mon 06:00, regardless of model.
    let week: UsageBucket
    /// Subset of `week` filtered to Sonnet variants only.
    let weekSonnet: UsageBucket
    /// Subset of `week` filtered to Opus variants — labelled "Claude Design"
    /// in the Anthropic dashboard.
    let weekOpus: UsageBucket
    /// Next Monday at 06:00 local time.
    let weekResetAt: Date

    let month: UsageBucket
    let allTime: UsageBucket
    let lastMessageAt: Date?
    let totalEntries: Int
    let generatedAt: Date
    /// User-configured session token allowance (e.g. Pro / Max 5x / Max 20x).
    /// `nil` means "don't display a limit, just the raw count".
    let sessionTokenLimit: Int?
    /// Weekly limits per category. `nil` when the user picked "Prozent-Anzeige aus".
    let weeklyAllLimit: Int?
    let weeklySonnetLimit: Int?
    let weeklyOpusLimit: Int?
}

/// User-selectable plan presets. Anthropic does not publish hard token caps;
/// these defaults are calibrated so the percentage display roughly matches
/// what claude.ai shows under "Plan-Nutzungslimits".
///
/// Calibration sample (May 2026, Max 5×):
///   43 M reported tokens corresponded to ~13 % in the Anthropic dashboard
///   → ~330 M as the inferred 100 %. Other tiers extrapolated from there.
///
/// You can override the limit per plan by editing this file or via the
/// "Plan" submenu in the status-item right-click menu. The percentage
/// shown in the popover and widget is an approximation; for the
/// authoritative number, see https://claude.ai/usage .
enum SessionPlan: String, CaseIterable {
    case pro    = "pro"
    case max5x  = "max5x"
    case max20x = "max20x"
    case hidden = "hidden"

    /// Per-5h-session token allowance.
    var tokenLimit: Int? {
        switch self {
        case .pro:    return    66_000_000
        case .max5x:  return   330_000_000
        case .max20x: return 1_320_000_000
        case .hidden: return nil
        }
    }

    /// Weekly "all models" cap — total tokens used between Mon 06:00 resets.
    /// Re-calibrated against a Max 5× sample showing 7 % at ~152 M tokens
    /// (May 2026): 152 M / 0.07 ≈ 2.17 Mrd → rounded to 2.0 Mrd as the
    /// tier baseline.
    var weeklyAllLimit: Int? {
        switch self {
        case .pro:    return    400_000_000
        case .max5x:  return  2_000_000_000
        case .max20x: return  8_000_000_000
        case .hidden: return nil
        }
    }

    /// Weekly "Sonnet only" cap. Anthropic gives Sonnet a separate, larger
    /// pool so heavy Sonnet users don't exhaust the all-models limit.
    /// Calibrated against the same sample showing 2 % at ~100 M Sonnet
    /// tokens → ~5 Mrd cap on Max 5×.
    var weeklySonnetLimit: Int? {
        switch self {
        case .pro:    return  1_000_000_000
        case .max5x:  return  5_000_000_000
        case .max20x: return 20_000_000_000
        case .hidden: return nil
        }
    }

    /// Weekly "Opus / Claude Design" cap. Smaller pool because Opus is
    /// the more expensive model. Estimate.
    var weeklyOpusLimit: Int? {
        switch self {
        case .pro:    return    100_000_000
        case .max5x:  return    500_000_000
        case .max20x: return  2_000_000_000
        case .hidden: return nil
        }
    }

    var displayName: String {
        switch self {
        case .pro:    return "Pro"
        case .max5x:  return "Max 5×"
        case .max20x: return "Max 20×"
        case .hidden: return "Prozent-Anzeige aus"
        }
    }
}
