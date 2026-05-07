import SwiftUI
import WidgetKit

// MARK: - Shared formatting

enum WFormat {
    static func compact(_ n: Int) -> String {
        let absN = abs(n)
        if absN >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000.0) }
        if absN >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000.0) }
        return "\(n)"
    }
    static func full(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    static func usd(_ d: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        nf.locale = Locale(identifier: "en_US")
        nf.maximumFractionDigits = d < 1 ? 3 : 2
        return nf.string(from: NSNumber(value: d)) ?? "$\(d)"
    }
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}

private let widgetBackground: some View = LinearGradient(
    colors: [Color(white: 0.10), Color(white: 0.05)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - Small (155 x 155)

struct SmallView: View {
    let entry: ClaudeUsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                Text(verbatim: "Claude")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            Spacer(minLength: 2)
            Text(verbatim: WFormat.compact(entry.sessionTokens))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(verbatim: "Tokens · Session")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer(minLength: 4)
            sessionFooter
        }
        .padding(.vertical, 4)
        .containerBackground(for: .widget) { widgetBackground }
    }

    @ViewBuilder
    private var sessionFooter: some View {
        if let reset = entry.sessionResetAt, let start = entry.sessionStart {
            let total: Double = 5 * 3600
            let progress = min(1, max(0, entry.date.timeIntervalSince(start) / total))
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: progress)
                    .tint(progress > 0.85 ? .orange : .white.opacity(0.85))
                    .scaleEffect(x: 1, y: 0.7, anchor: .center)
                HStack {
                    Text(verbatim: "Reset")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Text(verbatim: WFormat.clock(reset))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        } else {
            Text(verbatim: "Keine aktive Sitzung")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Medium (338 x 155)

struct MediumView: View {
    let entry: ClaudeUsageEntry

    var body: some View {
        HStack(spacing: 14) {
            // Left: session
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(verbatim: "Session")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(verbatim: WFormat.compact(entry.sessionTokens))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let reset = entry.sessionResetAt, let start = entry.sessionStart {
                    let total: Double = 5 * 3600
                    let progress = min(1, max(0, entry.date.timeIntervalSince(start) / total))
                    ProgressView(value: progress)
                        .tint(progress > 0.85 ? .orange : .white.opacity(0.85))
                        .scaleEffect(x: 1, y: 0.7, anchor: .center)
                    Text(verbatim: "Reset \(WFormat.clock(reset))")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(verbatim: "Keine aktive Sitzung")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(Color.white.opacity(0.15))

            // Right: today / week / month
            VStack(alignment: .leading, spacing: 8) {
                statRow("Heute",  tokens: entry.todayTokens, cost: entry.todayCost)
                statRow("Woche",  tokens: entry.weekTokens,  cost: entry.weekCost)
                statRow("Monat",  tokens: entry.monthTokens, cost: entry.monthCost)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(for: .widget) { widgetBackground }
    }

    private func statRow(_ label: String, tokens: Int, cost: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 38, alignment: .leading)
            Text(verbatim: WFormat.compact(tokens))
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundColor(.white)
            Spacer()
            Text(verbatim: WFormat.usd(cost))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.55))
        }
    }
}

// MARK: - Large (338 x 338)

struct LargeView: View {
    let entry: ClaudeUsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                Text(verbatim: "Claude Token Monitor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if let last = entry.lastActivity {
                    Text(verbatim: WFormat.clock(last))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Big session block
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: WFormat.full(entry.sessionTokens))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(verbatim: "Tokens in aktueller Session")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                if let reset = entry.sessionResetAt, let start = entry.sessionStart {
                    let total: Double = 5 * 3600
                    let progress = min(1, max(0, entry.date.timeIntervalSince(start) / total))
                    let remaining = max(0, reset.timeIntervalSince(entry.date))
                    let h = Int(remaining) / 3600
                    let m = (Int(remaining) % 3600) / 60
                    ProgressView(value: progress)
                        .tint(progress > 0.85 ? .orange : .white.opacity(0.85))
                        .scaleEffect(x: 1, y: 0.8, anchor: .center)
                    HStack {
                        Text(verbatim: "Noch \(h) h \(String(format: "%02d", m)) min")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(verbatim: "Reset \(WFormat.clock(reset))")
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    Text(verbatim: "Keine aktive Sitzung")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Divider().background(Color.white.opacity(0.12))

            // Period grid
            VStack(spacing: 8) {
                largeRow("Heute",  tokens: entry.todayTokens,   cost: entry.todayCost)
                largeRow("Woche",  tokens: entry.weekTokens,    cost: entry.weekCost)
                largeRow("Monat",  tokens: entry.monthTokens,   cost: entry.monthCost)
                largeRow("Gesamt", tokens: entry.allTimeTokens, cost: nil)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { widgetBackground }
    }

    private func largeRow(_ label: String, tokens: Int, cost: Double?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 60, alignment: .leading)
            Text(verbatim: WFormat.full(tokens))
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundColor(.white)
            Spacer()
            if let c = cost {
                Text(verbatim: WFormat.usd(c))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
}
