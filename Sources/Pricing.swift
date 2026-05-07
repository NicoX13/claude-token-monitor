import Foundation

// Approximate public pricing in USD per 1M tokens.
// Update if Anthropic changes pricing — these are baseline rates as of 2026.
struct ModelPricing {
    let input: Double          // per 1M
    let output: Double         // per 1M
    let cacheWrite5m: Double   // per 1M
    let cacheWrite1h: Double   // per 1M
    let cacheRead: Double      // per 1M
}

enum Pricing {
    // Conservative defaults — fall back to Sonnet pricing for unknown models.
    static let table: [String: ModelPricing] = [
        // Opus family
        "claude-opus-4-7":   ModelPricing(input: 15.00, output: 75.00, cacheWrite5m: 18.75, cacheWrite1h: 30.00, cacheRead: 1.50),
        "claude-opus-4-6":   ModelPricing(input: 15.00, output: 75.00, cacheWrite5m: 18.75, cacheWrite1h: 30.00, cacheRead: 1.50),
        "claude-opus-4-5":   ModelPricing(input: 15.00, output: 75.00, cacheWrite5m: 18.75, cacheWrite1h: 30.00, cacheRead: 1.50),
        "claude-opus-4-1":   ModelPricing(input: 15.00, output: 75.00, cacheWrite5m: 18.75, cacheWrite1h: 30.00, cacheRead: 1.50),
        "claude-opus-4":     ModelPricing(input: 15.00, output: 75.00, cacheWrite5m: 18.75, cacheWrite1h: 30.00, cacheRead: 1.50),
        // Sonnet family
        "claude-sonnet-4-6": ModelPricing(input:  3.00, output: 15.00, cacheWrite5m:  3.75, cacheWrite1h:  6.00, cacheRead: 0.30),
        "claude-sonnet-4-5": ModelPricing(input:  3.00, output: 15.00, cacheWrite5m:  3.75, cacheWrite1h:  6.00, cacheRead: 0.30),
        "claude-sonnet-4":   ModelPricing(input:  3.00, output: 15.00, cacheWrite5m:  3.75, cacheWrite1h:  6.00, cacheRead: 0.30),
        // Haiku family
        "claude-haiku-4-5":  ModelPricing(input:  1.00, output:  5.00, cacheWrite5m:  1.25, cacheWrite1h:  2.00, cacheRead: 0.10),
        "claude-haiku-4":    ModelPricing(input:  1.00, output:  5.00, cacheWrite5m:  1.25, cacheWrite1h:  2.00, cacheRead: 0.10),
    ]

    static let fallback = ModelPricing(input: 3.00, output: 15.00, cacheWrite5m: 3.75, cacheWrite1h: 6.00, cacheRead: 0.30)

    static func pricing(for model: String) -> ModelPricing {
        if let exact = table[model] { return exact }
        let lower = model.lowercased()
        if lower.contains("opus")   { return table["claude-opus-4-7"]! }
        if lower.contains("haiku")  { return table["claude-haiku-4-5"]! }
        if lower.contains("sonnet") { return table["claude-sonnet-4-6"]! }
        return fallback
    }

    /// Returns cost in USD. Cache creation pricing falls back to 5m rate when
    /// the JSONL doesn't separate ephemeral_5m vs ephemeral_1h tokens.
    static func cost(for entry: UsageEntry,
                     cache5m: Int = 0,
                     cache1h: Int = 0) -> Double {
        let p = pricing(for: entry.model)
        let inputCost   = Double(entry.inputTokens)        * p.input        / 1_000_000.0
        let outputCost  = Double(entry.outputTokens)       * p.output       / 1_000_000.0
        let readCost    = Double(entry.cacheReadTokens)    * p.cacheRead    / 1_000_000.0
        let writeCost: Double
        if cache5m + cache1h > 0 {
            writeCost = Double(cache5m) * p.cacheWrite5m / 1_000_000.0
                      + Double(cache1h) * p.cacheWrite1h / 1_000_000.0
        } else {
            writeCost = Double(entry.cacheCreationTokens) * p.cacheWrite5m / 1_000_000.0
        }
        return inputCost + outputCost + readCost + writeCost
    }
}
