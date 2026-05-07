import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: UsageViewModel
    @State private var tick: Date = Date()

    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            if let r = model.report {
                sessionSection(r)
                Divider()
                periodGrid(r)
                Divider()
                modelBreakdown(r)
                Divider()
                footer(r)
            } else {
                Text("Lade Daten…")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .frame(width: 360)
        .onReceive(refreshTimer) { tick = $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 0) {
                Text("Claude Token Monitor")
                    .font(.headline)
                Text("Lokal aus ~/.claude/projects")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("App beenden")
        }
    }

    // MARK: - Session

    @ViewBuilder
    private func sessionSection(_ r: UsageReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: r.isSessionActive
                     ? "Aktuelle Sitzung"
                     : "Letzte Sitzung (abgelaufen)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let reset = r.sessionResetAt {
                    Text(verbatim: r.isSessionActive
                         ? "Reset \(Formatter.clockTime(reset))"
                         : "Endete \(Formatter.clockTime(reset))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(Formatter.full(r.session.totalTokens))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let limit = r.sessionTokenLimit {
                    Text(verbatim: "/ \(Formatter.compact(limit))")
                        .font(.callout.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Text("Tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(verbatim: "\(r.session.messageCount) Nachr.")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Token-quota progress (only if a plan limit is set)
            if let limit = r.sessionTokenLimit, limit > 0 {
                let used = Double(r.session.totalTokens) / Double(limit)
                let clamped = min(1.0, max(0.0, used))
                ProgressView(value: clamped)
                    .tint(clamped > 0.85 ? .orange : .accentColor)
                Text(verbatim: "\(Int(clamped * 100)) % des Plan-Kontingents verbraucht")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Time progress: countdown when active, "ended X min ago" when expired.
            if let reset = r.sessionResetAt {
                if r.isSessionActive {
                    let remaining = max(0, reset.timeIntervalSince(tick))
                    let total: Double = 5 * 3600
                    let timeProgress = min(1.0, max(0.0, 1.0 - remaining / total))
                    ProgressView(value: timeProgress).tint(.gray)
                    Text(verbatim: "Noch \(timeRemainingString(remaining)) bis Sitzungs-Reset")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(verbatim: "Sitzung beendet \(elapsedSinceString(reset, now: tick)) — wartet auf nächsten Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(verbatim: "Noch keine Sitzung erfasst.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            tokenChips(bucket: r.session)
        }
    }

    private func elapsedSinceString(_ then: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(then)))
        if s < 60 { return "vor \(s) s" }
        if s < 3600 { return "vor \(s/60) min" }
        return "vor \(s/3600) h \(String(format: "%02d", (s%3600)/60)) min"
    }

    private func timeRemainingString(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = Int(s) % 60
        if h > 0 { return String(format: "%d h %02d min", h, m) }
        if m > 0 { return String(format: "%d min %02d s", m, sec) }
        return "\(sec) s"
    }

    // MARK: - Period Grid

    @ViewBuilder
    private func periodGrid(_ r: UsageReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verbrauch")
                .font(.subheadline.weight(.semibold))
            VStack(spacing: 0) {
                periodRow("Heute",  bucket: r.today)
                periodRow("Woche",  bucket: r.week)
                periodRow("Monat",  bucket: r.month)
                periodRow("Gesamt", bucket: r.allTime, isLast: true)
            }
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
        }
    }

    private func periodRow(_ label: String, bucket: UsageBucket, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.callout)
                    .frame(width: 64, alignment: .leading)
                Spacer()
                Text(Formatter.full(bucket.totalTokens))
                    .font(.callout.monospacedDigit())
                Text("Tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                Text(verbatim: "\(bucket.messageCount) Nachr.")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            if !isLast {
                Divider().opacity(0.4)
            }
        }
    }

    // MARK: - Token chips

    @ViewBuilder
    private func tokenChips(bucket: UsageBucket) -> some View {
        HStack(spacing: 6) {
            chip("In",         value: bucket.inputTokens,         color: .blue)
            chip("Out",        value: bucket.outputTokens,        color: .green)
            chip("Cache W",    value: bucket.cacheCreationTokens, color: .orange)
            chip("Cache R",    value: bucket.cacheReadTokens,     color: .purple)
        }
    }

    private func chip(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(Formatter.compact(value))
                .font(.caption.monospacedDigit())
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }

    // MARK: - Model breakdown

    @ViewBuilder
    private func modelBreakdown(_ r: UsageReport) -> some View {
        let models = r.allTime.perModel.sorted { $0.value.totalTokens > $1.value.totalTokens }
        if !models.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nach Modell (Gesamt)")
                    .font(.subheadline.weight(.semibold))
                ForEach(models.prefix(5), id: \.key) { (model, bucket) in
                    HStack {
                        // verbatim: never let attacker-controlled JSONL strings
                        // be parsed as a LocalizedStringKey / markdown.
                        Text(verbatim: modelLabel(model))
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(Formatter.full(bucket.totalTokens))
                            .font(.caption.monospacedDigit())
                        Text(verbatim: "\(bucket.messageCount) Nachr.")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func modelLabel(_ m: String) -> String {
        // claude-opus-4-7 -> Opus 4.7
        let lower = m.lowercased()
        let parts = lower.replacingOccurrences(of: "claude-", with: "").split(separator: "-")
        if parts.count >= 3 {
            let family = parts[0].capitalized
            let major = parts[1]
            let minor = parts[2]
            return "\(family) \(major).\(minor)"
        }
        return m
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(_ r: UsageReport) -> some View {
        HStack {
            if let last = r.lastMessageAt {
                Text("Letzte Aktivität \(Formatter.relativeTime(last, now: tick))")
            } else {
                Text("Noch keine Aktivität")
            }
            Spacer()
            Text("\(r.totalEntries) Messages")
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
}
