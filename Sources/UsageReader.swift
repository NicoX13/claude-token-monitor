import Foundation

final class UsageReader {

    private let projectsDir: URL
    private let iso: ISO8601DateFormatter

    /// Cache parsed entries per file, keyed by file path. Invalidated when the
    /// file size or mtime changes — appends are common, full rewrites are not.
    private struct FileCache {
        var size: Int
        var mtime: Date
        var entries: [UsageEntry]
        /// (cache5m, cache1h) per entry index, when present.
        var cacheBreakdown: [(Int, Int)]
    }
    private var fileCache: [String: FileCache] = [:]

    init(projectsDir: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.projectsDir = projectsDir ?? home.appendingPathComponent(".claude/projects")
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.iso = f
    }

    /// Walk all JSONL files and produce a fresh report.
    func generateReport(now: Date = Date()) -> UsageReport {
        let entries = loadAllEntries()
        return aggregate(entries: entries, now: now)
    }

    // MARK: - Loading

    private func loadAllEntries() -> [(UsageEntry, Int, Int)] {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]
        guard let projectDirs = try? fm.contentsOfDirectory(at: projectsDir,
                                                            includingPropertiesForKeys: Array(keys),
                                                            options: [.skipsHiddenFiles])
        else { return [] }

        // Confine all reads to the canonical projectsDir — refuse to follow
        // symlinks that escape the directory.
        let canonicalRoot = projectsDir.resolvingSymlinksInPath().standardizedFileURL.path

        var combined: [(UsageEntry, Int, Int)] = []
        var seenIds = Set<String>()
        seenIds.reserveCapacity(8192)

        for dir in projectDirs {
            let dirRes = try? dir.resourceValues(forKeys: keys)
            guard dirRes?.isDirectory == true else { continue }
            // Reject symlinks at the project-dir level.
            if dirRes?.isSymbolicLink == true { continue }
            // Path-traversal guard: resolved path must stay inside canonicalRoot.
            let resolvedDir = dir.resolvingSymlinksInPath().standardizedFileURL.path
            guard resolvedDir.hasPrefix(canonicalRoot) else { continue }

            guard let files = try? fm.contentsOfDirectory(at: dir,
                                                          includingPropertiesForKeys: Array(keys),
                                                          options: [.skipsHiddenFiles])
            else { continue }
            for file in files where file.pathExtension == "jsonl" {
                let fileRes = try? file.resourceValues(forKeys: keys)
                if fileRes?.isSymbolicLink == true { continue }
                if fileRes?.isRegularFile != true { continue }
                let resolvedFile = file.resolvingSymlinksInPath().standardizedFileURL.path
                guard resolvedFile.hasPrefix(canonicalRoot) else { continue }

                let parsed = parseFile(file)
                for (i, entry) in parsed.enumerated() {
                    let dedupKey = entry.messageId.isEmpty
                        ? "\(entry.timestamp.timeIntervalSince1970)|\(entry.requestId ?? "")"
                        : entry.messageId
                    if seenIds.insert(dedupKey).inserted == false { continue }
                    let breakdown = i < fileCache[file.path]?.cacheBreakdown.count ?? 0
                        ? fileCache[file.path]!.cacheBreakdown[i]
                        : (0, 0)
                    combined.append((entry, breakdown.0, breakdown.1))
                }
            }
        }

        return combined
    }

    /// Hard caps so a single malformed/malicious file can't blow up memory.
    private let maxFileSize: Int = 200 * 1024 * 1024     // 200 MiB
    private let maxLinesPerFile: Int = 200_000           // ~equals an extreme session count
    private let maxLineLength: Int = 4 * 1024 * 1024     // 4 MiB per JSONL line

    private func parseFile(_ file: URL) -> [UsageEntry] {
        let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attrs?[.size] as? Int) ?? -1
        let mtime = (attrs?[.modificationDate] as? Date) ?? Date.distantPast
        if let cached = fileCache[file.path],
           cached.size == size,
           cached.mtime == mtime {
            return cached.entries
        }
        // Refuse to load suspiciously huge files.
        if size > maxFileSize { return [] }

        guard let data = try? Data(contentsOf: file, options: [.mappedIfSafe]) else { return [] }
        var entries: [UsageEntry] = []
        var breakdown: [(Int, Int)] = []
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var lineCount = 0
        text.enumerateLines { line, stop in
            lineCount += 1
            if lineCount > self.maxLinesPerFile { stop = true; return }
            guard !line.isEmpty, line.utf8.count <= self.maxLineLength else { return }
            guard let lineData = line.data(using: .utf8),
                  let parsed = self.parseLine(lineData)
            else { return }
            entries.append(parsed.entry)
            breakdown.append((parsed.cache5m, parsed.cache1h))
        }
        fileCache[file.path] = FileCache(size: size, mtime: mtime,
                                         entries: entries, cacheBreakdown: breakdown)
        return entries
    }

    private struct ParsedLine {
        let entry: UsageEntry
        let cache5m: Int
        let cache1h: Int
    }

    /// Sanitise an attacker-controlled identifier: strip control chars and any
    /// character outside a strict allow-list, then truncate. We never feed this
    /// to a shell, JS, or LLM — but it gets rendered in the popover, so we still
    /// neutralise newlines / RTL overrides / other display tricks.
    private func sanitiseIdentifier(_ s: String, maxLen: Int) -> String {
        let allowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.:/")
        var out = String()
        out.reserveCapacity(min(s.count, maxLen))
        for ch in s {
            if out.count >= maxLen { break }
            if allowed.contains(ch) { out.append(ch) }
        }
        return out.isEmpty ? "unknown" : out
    }

    /// Cap a token counter at a sanity bound to defang malicious or buggy
    /// values (negative, NaN-ish, absurdly large).
    private func sanitiseTokenCount(_ raw: Any?) -> Int {
        let v: Int
        if let i = raw as? Int { v = i }
        else if let d = raw as? Double, d.isFinite { v = Int(max(0, min(d, 1e15))) }
        else { v = 0 }
        if v < 0 { return 0 }
        // 1 billion tokens per single API call is already 100x reality.
        if v > 1_000_000_000 { return 0 }
        return v
    }

    private func parseLine(_ data: Data) -> ParsedLine? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        guard (json["type"] as? String) == "assistant" else { return nil }
        guard let message = json["message"] as? [String: Any] else { return nil }
        guard let usage = message["usage"] as? [String: Any] else { return nil }

        let rawModel = (message["model"] as? String) ?? "unknown"
        let model = sanitiseIdentifier(rawModel, maxLen: 64)
        let messageId = sanitiseIdentifier((message["id"] as? String) ?? "", maxLen: 128)
        let requestId: String? = {
            guard let s = json["requestId"] as? String else { return nil }
            return sanitiseIdentifier(s, maxLen: 128)
        }()
        let sessionId = sanitiseIdentifier((json["sessionId"] as? String) ?? "", maxLen: 64)
        let timestampStr = (json["timestamp"] as? String) ?? ""
        // Timestamp is treated purely as data — only ISO formatters touch it.
        guard timestampStr.count <= 64,
              let date = iso.date(from: timestampStr) ?? alternativeDate(from: timestampStr)
        else { return nil }
        // Reject implausible timestamps (more than ~5 years off) so future
        // bucketing doesn't get poisoned.
        let now = Date()
        let drift: TimeInterval = 5 * 365 * 24 * 3600
        if abs(date.timeIntervalSince(now)) > drift { return nil }

        let input        = sanitiseTokenCount(usage["input_tokens"])
        let output       = sanitiseTokenCount(usage["output_tokens"])
        let cacheCreate  = sanitiseTokenCount(usage["cache_creation_input_tokens"])
        let cacheRead    = sanitiseTokenCount(usage["cache_read_input_tokens"])

        var cache5m = 0
        var cache1h = 0
        if let cc = usage["cache_creation"] as? [String: Any] {
            cache5m = sanitiseTokenCount(cc["ephemeral_5m_input_tokens"])
            cache1h = sanitiseTokenCount(cc["ephemeral_1h_input_tokens"])
        }

        // Skip rows where every counter is zero (synthetic / placeholder messages).
        if input == 0 && output == 0 && cacheCreate == 0 && cacheRead == 0 { return nil }

        let entry = UsageEntry(timestamp: date,
                               model: model,
                               inputTokens: input,
                               outputTokens: output,
                               cacheCreationTokens: cacheCreate,
                               cacheReadTokens: cacheRead,
                               messageId: messageId,
                               requestId: requestId,
                               sessionId: sessionId)
        return ParsedLine(entry: entry, cache5m: cache5m, cache1h: cache1h)
    }

    private func alternativeDate(from s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    // MARK: - Aggregation

    private func aggregate(entries: [(UsageEntry, Int, Int)], now: Date) -> UsageReport {
        let cal = Calendar(identifier: .iso8601)
        var startOfToday = cal.startOfDay(for: now)
        // Ensure local-time start of day
        startOfToday = cal.startOfDay(for: now)

        // Start of ISO week (Monday) in local time
        var weekComp = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        weekComp.weekday = 2 // Monday in Gregorian; .iso8601 uses Monday-first
        let startOfWeek = cal.date(from: weekComp) ?? startOfToday

        var monthComp = cal.dateComponents([.year, .month], from: now)
        monthComp.day = 1
        let startOfMonth = cal.date(from: monthComp) ?? startOfToday

        // Sort by time ascending, then chunk into Anthropic-style fixed-5h
        // session windows. A new session begins when the message's timestamp
        // is at or after the end of the last session — i.e. the previous
        // session has elapsed and this prompt opens a new 5h window.
        let sortedAsc = entries.sorted { $0.0.timestamp < $1.0.timestamp }
        let sessionWindow: TimeInterval = 5 * 3600

        struct WindowRange { let start: Date; let end: Date }
        var sessions: [WindowRange] = []
        for (e, _, _) in sortedAsc {
            if let last = sessions.last, e.timestamp < last.end {
                // still inside the most recent session window
            } else {
                sessions.append(WindowRange(start: e.timestamp,
                                            end: e.timestamp.addingTimeInterval(sessionWindow)))
            }
        }
        let mostRecent = sessions.last
        let isSessionActive = mostRecent.map { now < $0.end } ?? false
        let sessionStart = mostRecent?.start
        let sessionResetAt = mostRecent?.end

        var session = UsageBucket()
        var today = UsageBucket()
        var week = UsageBucket()
        var month = UsageBucket()
        var allTime = UsageBucket()

        for (e, c5, c1) in sortedAsc {
            let cost = Pricing.cost(for: e, cache5m: c5, cache1h: c1)
            allTime.add(e, cost: cost)
            if e.timestamp >= startOfMonth { month.add(e, cost: cost) }
            if e.timestamp >= startOfWeek  { week.add(e, cost: cost) }
            if e.timestamp >= startOfToday { today.add(e, cost: cost) }
            // Session bucket = only the most recent session window, regardless
            // of whether it's still active or already elapsed. The active flag
            // tells the UI which label to use.
            if let s = mostRecent,
               e.timestamp >= s.start,
               e.timestamp <  s.end {
                session.add(e, cost: cost)
            }
        }

        // Resolve the user-selected plan (default Max 20× — most users of
        // Claude Code today are on Max-tier subscriptions; can be changed
        // via the status-item right-click menu).
        let planRaw = UserDefaults.standard.string(forKey: "SessionPlan") ?? SessionPlan.max5x.rawValue
        let plan = SessionPlan(rawValue: planRaw) ?? .max5x

        return UsageReport(session: session,
                           sessionStart: sessionStart,
                           sessionResetAt: sessionResetAt,
                           isSessionActive: isSessionActive,
                           today: today,
                           week: week,
                           month: month,
                           allTime: allTime,
                           lastMessageAt: sortedAsc.last?.0.timestamp,
                           totalEntries: sortedAsc.count,
                           generatedAt: now,
                           sessionTokenLimit: plan.tokenLimit)
    }
}
