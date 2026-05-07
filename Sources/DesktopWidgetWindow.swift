import AppKit
import SwiftUI

/// A borderless, rounded, dark window that lives on the desktop layer.
///
/// macOS won't let us register a true WidgetKit extension without an Apple
/// Developer ID (AMFI rejects ad-hoc signed extensions), so we approximate the
/// look of a native widget with a normal NSWindow that:
///   - is borderless and transparent,
///   - sits on the desktop level (above the wallpaper, below app windows),
///   - is draggable so the user can place it on the left of the screen,
///   - persists its position across launches.
final class DesktopWidgetWindow: NSObject {

    enum Size: String {
        case small  = "small"     // 165 x 165
        case medium = "medium"    // 348 x 165
        case large  = "large"     // 348 x 348

        var dimensions: NSSize {
            switch self {
            case .small:  return NSSize(width: 165, height: 165)
            case .medium: return NSSize(width: 348, height: 165)
            case .large:  return NSSize(width: 348, height: 348)
            }
        }
    }

    /// Routed to AppDelegate when the user picks something from the widget's
    /// own right-click context menu.
    enum MenuAction {
        case toggleVisibility
        case snapTopLeft
        case setSize(Size)
        case openDetails
        case quit
    }

    private(set) var window: NSWindow!
    private let viewModel: UsageViewModel
    private let prefsKey = "DesktopWidgetFrame"
    private let sizePrefsKey = "DesktopWidgetSize"
    private let actionHandler: (MenuAction) -> Void

    init(viewModel: UsageViewModel,
         defaultSize: Size = .medium,
         onMenuAction: @escaping (MenuAction) -> Void) {
        self.viewModel = viewModel
        self.actionHandler = onMenuAction
        super.init()

        let savedSizeRaw = UserDefaults.standard.string(forKey: sizePrefsKey)
        let size = Size(rawValue: savedSizeRaw ?? "") ?? defaultSize

        let dim = size.dimensions
        let initialOrigin = preferredOrigin(for: dim)
        let frame = NSRect(origin: initialOrigin, size: dim)

        let win = DraggableWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        // Disable the OS-drawn window shadow — it traces the alpha edge of the
        // SwiftUI content and produces a hard outline. SwiftUI .shadow renders
        // a soft drop shadow instead.
        win.hasShadow = false
        win.isMovableByWindowBackground = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // Sit on the "desktop icon" level — above the wallpaper, below normal
        // windows. Use a level just below normal so other apps overlap us
        // naturally.
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        win.title = "Claude Token Widget"

        // Use NSHostingView directly so SwiftUI cannot shrink the window to
        // its intrinsic content size. The view fills via autoresizing.
        let hostView = NSHostingView(rootView: DesktopWidgetView(model: viewModel, size: size))
        hostView.frame = NSRect(origin: .zero, size: dim)
        hostView.autoresizingMask = [.width, .height]
        hostView.translatesAutoresizingMaskIntoConstraints = true
        win.contentView = hostView
        win.contentView?.wantsLayer = true

        // Wire right-click to our context menu. Borderless windows that can't
        // become key still receive mouse events, but rightMouseDown isn't
        // dispatched up the responder chain by default — we handle it on the
        // window itself.
        win.onRightMouseDown = { [weak self] location in
            self?.showContextMenu(at: location)
        }

        // Restore saved frame if we have one and it still fits the screen.
        if let saved = UserDefaults.standard.string(forKey: prefsKey),
           let parsed = NSRectFromString(saved) as NSRect?,
           parsed.size != .zero,
           NSScreen.screens.contains(where: { $0.visibleFrame.intersects(parsed) }) {
            win.setFrame(parsed, display: false)
        }

        win.delegate = self
        self.window = win
    }

    func show() {
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    /// Snap the window to the upper-left of the main screen with a margin.
    func snapToTopLeft() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let dim = window.frame.size
        let origin = NSPoint(x: visible.minX + 24,
                             y: visible.maxY - dim.height - 24)
        window.setFrame(NSRect(origin: origin, size: dim), display: true, animate: true)
        persistFrame()
    }

    /// Change widget size at runtime. Recreates the SwiftUI hosting view.
    func setSize(_ size: Size) {
        UserDefaults.standard.set(size.rawValue, forKey: sizePrefsKey)
        let newDim = size.dimensions
        var f = window.frame
        // Keep top-left corner stable when resizing.
        let topY = f.maxY
        f.size = newDim
        f.origin.y = topY - newDim.height
        window.setFrame(f, display: true, animate: true)
        let hostView = NSHostingView(rootView: DesktopWidgetView(model: viewModel, size: size))
        hostView.frame = NSRect(origin: .zero, size: newDim)
        hostView.autoresizingMask = [.width, .height]
        hostView.translatesAutoresizingMaskIntoConstraints = true
        window.contentView = hostView
        persistFrame()
    }

    private func preferredOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let v = screen.visibleFrame
        return NSPoint(x: v.minX + 24, y: v.maxY - size.height - 24)
    }

    fileprivate func persistFrame() {
        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: prefsKey)
    }

    // MARK: - Context menu

    private func showContextMenu(at location: NSPoint) {
        let menu = NSMenu()

        let toggle = menuItem("Widget ausblenden", action: #selector(menuToggle))
        menu.addItem(toggle)

        let snap = menuItem("Oben links anheften", action: #selector(menuSnapTopLeft))
        menu.addItem(snap)

        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: "Größe", action: nil, keyEquivalent: "")
        let sizeSub = NSMenu()
        let currentSize = Size(rawValue: UserDefaults.standard.string(forKey: sizePrefsKey) ?? "") ?? .medium
        for (title, raw) in [("Klein",  "small"),
                             ("Mittel", "medium"),
                             ("Groß",   "large")] {
            let it = menuItem(title, action: #selector(menuSetSize(_:)))
            it.representedObject = raw
            it.state = (raw == currentSize.rawValue) ? .on : .off
            sizeSub.addItem(it)
        }
        sizeItem.submenu = sizeSub
        menu.addItem(sizeItem)

        menu.addItem(.separator())

        let details = menuItem("Details öffnen", action: #selector(menuOpenDetails))
        menu.addItem(details)

        menu.addItem(.separator())

        let quit = menuItem("Beenden", action: #selector(menuQuit))
        menu.addItem(quit)

        // Pop up at the click location in window coordinates. We use
        // popUp(positioning:at:in:) so the menu doesn't depend on the window
        // becoming key.
        menu.popUp(positioning: nil, at: location, in: window.contentView)
    }

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        return it
    }

    @objc private func menuToggle()       { actionHandler(.toggleVisibility) }
    @objc private func menuSnapTopLeft()  { actionHandler(.snapTopLeft) }
    @objc private func menuOpenDetails()  { actionHandler(.openDetails) }
    @objc private func menuQuit()         { actionHandler(.quit) }
    @objc private func menuSetSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = Size(rawValue: raw) else { return }
        actionHandler(.setSize(size))
    }
}

extension DesktopWidgetWindow: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) { persistFrame() }
    func windowDidResize(_ notification: Notification) { persistFrame() }
}

/// NSWindow subclass that:
///   - reports `canBecomeKey/Main = false` so it never steals focus,
///   - dispatches `rightMouseDown` to its `onRightMouseDown` callback so a
///     non-key window can still show a context menu.
private final class DraggableWindow: NSWindow {
    /// Called with the click location in window-local coordinates.
    var onRightMouseDown: ((NSPoint) -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        let pointInWindow = event.locationInWindow
        onRightMouseDown?(pointInWindow)
    }
}

// MARK: - SwiftUI shell

private struct DesktopWidgetView: View {
    @ObservedObject var model: UsageViewModel
    let size: DesktopWidgetWindow.Size
    @State private var tick: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // Geometry scales the rounded shell to the widget footprint.
        // Apple's own widgets use bigger corner radii on larger sizes;
        // we follow the same proportions (~7–8 % of the smaller side).
        let cornerRadius: CGFloat = {
            switch size {
            case .small:  return 22
            case .medium: return 24
            case .large:  return 28
            }
        }()
        let outerPadding: CGFloat = {
            switch size {
            case .small:  return 6
            case .medium: return 8
            case .large:  return 10
            }
        }()
        let shadowRadius: CGFloat = {
            switch size {
            case .small:  return 14
            case .medium: return 18
            case .large:  return 24
            }
        }()
        return ZStack {
            if let r = model.report {
                let entry = makeEntry(from: r)
                switch size {
                case .small:  WidgetSmall(entry: entry)
                case .medium: WidgetMedium(entry: entry)
                case .large:  WidgetLarge(entry: entry)
                }
            } else {
                Text(verbatim: "…")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.10), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.4),
                radius: shadowRadius, x: 0, y: shadowRadius * 0.4)
        .padding(outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { tick = $0 }
    }

    private func makeEntry(from r: UsageReport) -> DesktopEntry {
        DesktopEntry(
            now: tick,
            sessionTokens: r.session.totalTokens,
            sessionMessages: r.session.messageCount,
            sessionStart: r.sessionStart,
            sessionResetAt: r.sessionResetAt,
            isSessionActive: r.isSessionActive,
            sessionTokenLimit: r.sessionTokenLimit,
            weekTokens: r.week.totalTokens,
            weekMessages: r.week.messageCount,
            weekSonnetTokens: r.weekSonnet.totalTokens,
            weekOpusTokens: r.weekOpus.totalTokens,
            weekResetAt: r.weekResetAt,
            weeklyAllLimit: r.weeklyAllLimit,
            weeklySonnetLimit: r.weeklySonnetLimit,
            weeklyOpusLimit: r.weeklyOpusLimit,
            lastActivity: r.lastMessageAt
        )
    }
}

struct DesktopEntry {
    let now: Date
    let sessionTokens: Int
    let sessionMessages: Int
    let sessionStart: Date?
    let sessionResetAt: Date?
    let isSessionActive: Bool
    let sessionTokenLimit: Int?
    // Weekly buckets — Anthropic-style three-row breakdown.
    let weekTokens: Int
    let weekMessages: Int
    let weekSonnetTokens: Int
    let weekOpusTokens: Int
    let weekResetAt: Date
    let weeklyAllLimit: Int?
    let weeklySonnetLimit: Int?
    let weeklyOpusLimit: Int?
    let lastActivity: Date?

    // MARK: - Helpers

    /// Approximate "% of session quota used" — `nil` when limit hidden.
    var percentUsed: Int? {
        guard let limit = sessionTokenLimit, limit > 0 else { return nil }
        let v = Double(sessionTokens) / Double(limit)
        return Int((min(1.0, max(0.0, v)) * 100).rounded())
    }
    func percent(_ used: Int, of limit: Int?) -> Int? {
        guard let l = limit, l > 0 else { return nil }
        return Int((min(1.0, max(0.0, Double(used) / Double(l))) * 100).rounded())
    }
}

// MARK: - Sizes

private struct WidgetSmall: View {
    let entry: DesktopEntry
    var body: some View {
        let pct = entry.percentUsed
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
            // Hero number: percent if a plan is set, else compact tokens.
            if let p = pct {
                Text(verbatim: "\(p) %")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(p > 85 ? .orange : .white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(verbatim: "verwendet · Session")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            } else {
                Text(verbatim: WCompact.compact(entry.sessionTokens))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(verbatim: "Tokens · Session")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 4)
            sessionFooter(pct: pct)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    @ViewBuilder
    private func sessionFooter(pct: Int?) -> some View {
        if let reset = entry.sessionResetAt {
            // Progress bar mirrors the hero — tokens-percent when a plan is
            // set, otherwise falls back to the elapsed time within the 5h
            // window (which is what the user has from a non-plan POV).
            let progress: Double = {
                if let p = pct { return Double(p) / 100.0 }
                if let start = entry.sessionStart {
                    let total: Double = 5 * 3600
                    return min(1, max(0, entry.now.timeIntervalSince(start) / total))
                }
                return 0
            }()
            VStack(alignment: .leading, spacing: 4) {
                WBar(value: progress,
                     color: progress > 0.85 ? .orange : .white.opacity(0.85),
                     thickness: 4)
                HStack {
                    Text(verbatim: entry.isSessionActive ? "Reset" : "Endete")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer()
                    Text(verbatim: WCompact.clock(reset))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        } else {
            Text(verbatim: "Keine Sitzung")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

private struct WidgetMedium: View {
    let entry: DesktopEntry
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(verbatim: entry.isSessionActive ? "Aktive Sitzung" : "Letzte Sitzung")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                let pct = entry.percentUsed
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let p = pct {
                        Text(verbatim: "\(p) %")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(p > 85 ? .orange : .white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(verbatim: "verwendet")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text(verbatim: WCompact.compact(entry.sessionTokens))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(verbatim: "Tokens")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                if let reset = entry.sessionResetAt {
                    let progress: Double = {
                        if let p = pct { return Double(p) / 100.0 }
                        if let start = entry.sessionStart {
                            let total: Double = 5 * 3600
                            return min(1, max(0, entry.now.timeIntervalSince(start) / total))
                        }
                        return 0
                    }()
                    WBar(value: progress,
                         color: progress > 0.85 ? .orange : .white.opacity(0.85),
                         thickness: 5)
                    Text(verbatim: "\(WCompact.compact(entry.sessionTokens)) Tokens · \(entry.sessionMessages) Nachr.")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                    Text(verbatim: entry.isSessionActive
                         ? "Reset \(WCompact.clock(reset))"
                         : "Endete \(WCompact.clock(reset))")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(verbatim: "Keine Sitzung erfasst")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().background(Color.white.opacity(0.15))
            // Right column = weekly limits, mirroring the Anthropic dashboard
            // ("Wöchentliche Limits"). Three rows (Alle/Sonnet/Opus) with
            // percent + thin progress bar. The Mon-06:00 reset is implicit
            // via the section title; we keep the rows compact.
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: "Wöchentlich")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                weeklyRow("Alle Modelle",
                          pct: entry.percent(entry.weekTokens, of: entry.weeklyAllLimit),
                          fallbackText: nil)
                weeklyRow("Nur Sonnet",
                          pct: entry.percent(entry.weekSonnetTokens, of: entry.weeklySonnetLimit),
                          fallbackText: entry.weekSonnetTokens == 0 ? "nicht genutzt" : nil)
                weeklyRow("Nur Opus",
                          pct: entry.percent(entry.weekOpusTokens, of: entry.weeklyOpusLimit),
                          fallbackText: entry.weekOpusTokens == 0 ? "nicht genutzt" : nil)
                Spacer(minLength: 0)
                Text(verbatim: "Reset Mo., 06:00")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func weeklyRow(_ label: String, pct: Int?, fallbackText: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                if let p = pct {
                    Text(verbatim: "\(p) %")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(p > 85 ? .orange : .white)
                } else if let txt = fallbackText {
                    Text(verbatim: txt)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            WBar(value: Double(pct ?? 0) / 100.0,
                 color: (pct ?? 0) > 85 ? .orange : .white.opacity(0.7),
                 thickness: 4)
        }
    }
}

private struct WidgetLarge: View {
    let entry: DesktopEntry
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
                    Text(verbatim: WCompact.clock(last))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                let pct = entry.percentUsed
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let p = pct {
                        Text(verbatim: "\(p) %")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(p > 85 ? .orange : .white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(verbatim: "verwendet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text(verbatim: WCompact.full(entry.sessionTokens))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(verbatim: "Tokens")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                Text(verbatim: entry.isSessionActive
                     ? "Aktuelle Sitzung"
                     : "Letzte Sitzung (abgelaufen)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                if let reset = entry.sessionResetAt {
                    let progress: Double = {
                        if let p = pct { return Double(p) / 100.0 }
                        if let start = entry.sessionStart {
                            let total: Double = 5 * 3600
                            return min(1, max(0, entry.now.timeIntervalSince(start) / total))
                        }
                        return 0
                    }()
                    WBar(value: progress,
                         color: progress > 0.85 ? .orange : .white.opacity(0.85),
                         thickness: 6)
                    Text(verbatim: "\(WCompact.compact(entry.sessionTokens)) Tokens · \(entry.sessionMessages) Nachr.")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                    if entry.isSessionActive {
                        let remaining = max(0, reset.timeIntervalSince(entry.now))
                        let h = Int(remaining) / 3600
                        let m = (Int(remaining) % 3600) / 60
                        HStack {
                            Text(verbatim: "Noch \(h) h \(String(format: "%02d", m)) min")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(verbatim: "Reset \(WCompact.clock(reset))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else {
                        let elapsed = max(0, entry.now.timeIntervalSince(reset))
                        let h = Int(elapsed) / 3600
                        let m = (Int(elapsed) % 3600) / 60
                        let elapsedStr = h > 0
                            ? "vor \(h) h \(String(format: "%02d", m)) min"
                            : "vor \(m) min"
                        HStack {
                            Text(verbatim: "Beendet \(elapsedStr)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(verbatim: "Endete \(WCompact.clock(reset))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                } else {
                    Text(verbatim: "Noch keine Sitzung erfasst")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Divider().background(Color.white.opacity(0.12))

            // Wöchentliche Limits (Anthropic-Layout)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Wöchentliche Limits")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(verbatim: "nur Claude Code")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
                largeWeeklyRow(label: "Alle Modelle",
                               pct: entry.percent(entry.weekTokens, of: entry.weeklyAllLimit),
                               fallbackText: nil)
                largeWeeklyRow(label: "Nur Sonnet",
                               pct: entry.percent(entry.weekSonnetTokens, of: entry.weeklySonnetLimit),
                               fallbackText: entry.weekSonnetTokens == 0 ? "via Claude Code noch nicht genutzt" : nil)
                largeWeeklyRow(label: "Nur Opus",
                               pct: entry.percent(entry.weekOpusTokens, of: entry.weeklyOpusLimit),
                               fallbackText: entry.weekOpusTokens == 0 ? "via Claude Code noch nicht genutzt" : nil)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    /// Always renders the "Zurücksetzung Mo., 06:00" subtitle when there's
    /// usage; falls back to the per-row "diese Woche nicht genutzt" when the
    /// bucket is empty. Mirrors the popover layout so the widget never has
    /// rows missing a subtitle (which looked broken in earlier builds).
    private func largeWeeklyRow(label: String,
                                pct: Int?,
                                fallbackText: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text(verbatim: fallbackText ?? "Zurücksetzung Mo., 06:00")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                if let p = pct {
                    Text(verbatim: "\(p) % verwendet")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundColor(p > 85 ? .orange : .white.opacity(0.85))
                }
            }
            WBar(value: Double(pct ?? 0) / 100.0,
                 color: (pct ?? 0) > 85 ? .orange : .white.opacity(0.7),
                 thickness: 5)
        }
    }
}

// MARK: - Local formatters (kept separate from Formatter in AppDelegate.swift to
// avoid coupling the desktop widget to the popover module).

enum WCompact {
    /// German-style compact token formatter. Uses "Mio" / "Tsd" so the unit
    /// can never be confused with the message-count abbreviation ("Nachr.").
    static func compact(_ n: Int) -> String {
        let absN = abs(n)
        if absN >= 1_000_000 {
            return String(format: "%.1f Mio", Double(n) / 1_000_000.0)
                .replacingOccurrences(of: ".", with: ",")
        }
        if absN >= 1_000 {
            return String(format: "%.1f Tsd", Double(n) / 1_000.0)
                .replacingOccurrences(of: ".", with: ",")
        }
        return "\(n)"
    }
    static func full(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}

/// Custom progress bar — `ProgressView` renders an extremely thin track on
/// macOS (≈2 pt after the `.scaleEffect(y: 0.55–0.8)` we used to apply),
/// which made the widget bars almost invisible against the dark background.
/// This replacement is a fixed-height Capsule with controllable thickness.
struct WBar: View {
    let value: Double          // 0 … 1
    let color: Color
    var thickness: CGFloat = 5
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: min(1, max(0, value)) * geo.size.width)
            }
        }
        .frame(height: thickness)
    }
}
