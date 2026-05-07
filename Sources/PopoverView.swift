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
                weeklyLimitsSection(r)
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
        .frame(width: 380)
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
        let percent: Int? = {
            guard let limit = r.sessionTokenLimit, limit > 0 else { return nil }
            let v = Double(r.session.totalTokens) / Double(limit)
            return Int((min(1.0, max(0.0, v)) * 100).rounded())
        }()
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: "Plan-Nutzungslimits")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(verbatim: planLabel(r))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Aktuelle Sitzung row in Anthropic style.
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: r.isSessionActive
                             ? "Aktuelle Sitzung"
                             : "Letzte Sitzung (abgelaufen)")
                            .font(.callout.weight(.semibold))
                        if let reset = r.sessionResetAt {
                            if r.isSessionActive {
                                Text(verbatim: "Zurücksetzung in \(remainingString(reset.timeIntervalSince(tick)))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(verbatim: "Beendet \(elapsedSinceString(reset, now: tick))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(verbatim: "Noch keine Sitzung erfasst")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let p = percent {
                        Text(verbatim: "\(p) % verwendet")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(p > 85 ? .orange : .secondary)
                    } else {
                        Text(verbatim: "\(Formatter.compact(r.session.totalTokens)) Tokens")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
                if let p = percent {
                    ProgressView(value: Double(p) / 100.0)
                        .tint(p > 85 ? .orange : .accentColor)
                } else {
                    ProgressView(value: 0).tint(.gray)
                }
            }
        }
    }

    private func planLabel(_ r: UsageReport) -> String {
        let raw = UserDefaults.standard.string(forKey: "SessionPlan") ?? SessionPlan.max5x.rawValue
        return SessionPlan(rawValue: raw)?.displayName ?? "Max 5×"
    }

    /// "3 Std. 16 Min." — matches Anthropic copy.
    private func remainingString(_ s: TimeInterval) -> String {
        let total = max(0, Int(s))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) Std. \(m) Min." }
        if m > 0 { return "\(m) Min." }
        return "\(total) Sek."
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

    // MARK: - Weekly limits (Anthropic dashboard parity)

    @ViewBuilder
    private func weeklyLimitsSection(_ r: UsageReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "Wöchentliche Limits")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(verbatim: "nur Claude Code")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            limitRow(label: "Alle Modelle",
                     bucket: r.week,
                     limit: r.weeklyAllLimit,
                     resetAt: r.weekResetAt,
                     emptyText: nil)

            limitRow(label: "Nur Sonnet",
                     bucket: r.weekSonnet,
                     limit: r.weeklySonnetLimit,
                     resetAt: r.weekResetAt,
                     emptyText: r.weekSonnet.messageCount == 0
                        ? "via Claude Code noch nicht genutzt" : nil)

            limitRow(label: "Nur Opus",
                     bucket: r.weekOpus,
                     limit: r.weeklyOpusLimit,
                     resetAt: r.weekResetAt,
                     emptyText: r.weekOpus.messageCount == 0
                        ? "via Claude Code noch nicht genutzt" : nil)

            Text(verbatim: "Web-/Desktop-Nutzung von Claude wird nicht erfasst — exakte Werte unter claude.ai/usage.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func limitRow(label: String,
                          bucket: UsageBucket,
                          limit: Int?,
                          resetAt: Date,
                          emptyText: String?) -> some View {
        let percent: Int? = {
            guard let l = limit, l > 0 else { return nil }
            let v = Double(bucket.totalTokens) / Double(l) * 100
            return Int(min(100, max(0, v.rounded())))
        }()
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: label)
                        .font(.callout.weight(.semibold))
                    if let txt = emptyText {
                        Text(verbatim: txt)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(verbatim: "Zurücksetzung \(weekdayShort(resetAt)), \(Formatter.clockTime(resetAt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if let p = percent {
                    Text(verbatim: "\(p) % verwendet")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(p > 85 ? .orange : .secondary)
                } else {
                    Text(verbatim: "\(Formatter.compact(bucket.totalTokens)) Tokens")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }
            if let p = percent {
                ProgressView(value: Double(p) / 100.0)
                    .tint(p > 85 ? .orange : .accentColor)
            } else {
                ProgressView(value: 0).tint(.gray)
            }
        }
    }

    /// "Mo." / "Di." / etc. — Anthropic uses German short weekday names.
    private func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEEEE"     // "Mo"
        let s = f.string(from: date)
        return s.hasSuffix(".") ? s : s + "."
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
