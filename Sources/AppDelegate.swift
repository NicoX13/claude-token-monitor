import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var refreshTimer: Timer?
    private var fsWatcher: DispatchSourceFileSystemObject?
    private var watcherFD: Int32 = -1
    private let reader = UsageReader()
    private let viewModel = UsageViewModel()
    private var desktopWidget: DesktopWidgetWindow?
    private let desktopWidgetEnabledKey = "DesktopWidgetEnabled"
    /// Coalesce multiple FS events into one refresh so a burst of writes
    /// doesn't queue dozens of redundant parses.
    private var fsRefreshScheduled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — we live in the menu bar only.
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = makeTemplateIcon()
            button.image?.isTemplate = true
            button.imagePosition = .imageLeft
            button.title = " …"
            button.font = NSFont.menuBarFont(ofSize: 12)
            // Right-click → menu, left-click → popover.
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: viewModel)
        )

        // Default: desktop widget is enabled on first launch.
        if UserDefaults.standard.object(forKey: desktopWidgetEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: desktopWidgetEnabledKey)
        }
        if UserDefaults.standard.bool(forKey: desktopWidgetEnabledKey) {
            showDesktopWidget()
        }

        refresh()
        startRefreshTimer()
        startFileSystemWatcher()
        registerSystemNotifications()
    }

    // MARK: - Refresh strategy
    //
    // Three layers, designed so the popover and widget never go stale:
    //   1. Fast polling (5 s) on RunLoop.main in .common mode so it keeps
    //      firing while menus are open, during modal sheets, etc.
    //   2. FSEvents-style watcher on ~/.claude/projects: when Claude Code
    //      appends a JSONL line, we refresh within ~1 s instead of waiting
    //      for the next poll tick.
    //   3. Wake / activate notifications: macOS aggressively pauses timers
    //      when the machine sleeps; we re-poll immediately on wake or when
    //      the user brings our app forward.

    private func startRefreshTimer() {
        // 60 s is the safety-net poll. The FS watcher below already gives
        // sub-second updates whenever Claude Code writes to a JSONL file,
        // so we only need polling as a fallback for cases where the
        // watcher might miss something (network mounts, sleep/wake races).
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // .common = fires during menu tracking, modal sessions, scroll-event
        // loops — the situations where .default would silently pause.
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func startFileSystemWatcher() {
        let projectsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
        let fd = open(projectsDir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        watcherFD = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            self?.scheduleCoalescedRefresh()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.watcherFD, fd >= 0 { close(fd) }
            self?.watcherFD = -1
        }
        source.resume()
        fsWatcher = source
    }

    /// Many file events can arrive in <1 s while a JSONL is being written.
    /// Coalesce them into a single refresh to avoid pile-up.
    private func scheduleCoalescedRefresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.fsRefreshScheduled else { return }
            self.fsRefreshScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.fsRefreshScheduled = false
                self?.refresh()
            }
        }
    }

    private func registerSystemNotifications() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                             object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        wsCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                             object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu(sender)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            refresh()
            popover.show(relativeTo: button.bounds,
                         of: button,
                         preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Status menu (right-click)

    private func showStatusMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        let widgetEnabled = desktopWidget != nil

        let toggle = NSMenuItem(
            title: widgetEnabled ? "Desktop-Widget ausblenden" : "Desktop-Widget anzeigen",
            action: #selector(toggleDesktopWidget),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        if widgetEnabled {
            let snap = NSMenuItem(title: "Widget oben links anheften",
                                  action: #selector(snapWidgetTopLeft), keyEquivalent: "")
            snap.target = self
            menu.addItem(snap)

            menu.addItem(NSMenuItem.separator())

            let sizeItem = NSMenuItem(title: "Widget-Größe", action: nil, keyEquivalent: "")
            let sizeMenu = NSMenu()
            for (title, raw) in [("Klein",  "small"),
                                 ("Mittel", "medium"),
                                 ("Groß",   "large")] {
                let it = NSMenuItem(title: title,
                                    action: #selector(setWidgetSize(_:)),
                                    keyEquivalent: "")
                it.representedObject = raw
                it.target = self
                sizeMenu.addItem(it)
            }
            sizeItem.submenu = sizeMenu
            menu.addItem(sizeItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Plan submenu — picks the per-session token allowance shown as
        // "X / Y Tokens" + progress bar.
        let planItem = NSMenuItem(title: "Plan", action: nil, keyEquivalent: "")
        let planMenu = NSMenu()
        let currentPlan = SessionPlan(rawValue: UserDefaults.standard.string(forKey: "SessionPlan")
                                      ?? SessionPlan.max20x.rawValue) ?? .max20x
        for plan in SessionPlan.allCases {
            let it = NSMenuItem(title: plan.displayName,
                                action: #selector(setPlan(_:)),
                                keyEquivalent: "")
            it.representedObject = plan.rawValue
            it.state = (plan == currentPlan) ? .on : .off
            it.target = self
            planMenu.addItem(it)
        }
        planItem.submenu = planMenu
        menu.addItem(planItem)

        menu.addItem(NSMenuItem.separator())
        let details = NSMenuItem(title: "Details öffnen", action: #selector(togglePopoverFromMenu),
                                 keyEquivalent: "")
        details.target = self
        menu.addItem(details)

        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleDesktopWidget() {
        if desktopWidget != nil {
            hideDesktopWidget()
            UserDefaults.standard.set(false, forKey: desktopWidgetEnabledKey)
        } else {
            showDesktopWidget()
            UserDefaults.standard.set(true, forKey: desktopWidgetEnabledKey)
        }
    }

    @objc private func snapWidgetTopLeft() { desktopWidget?.snapToTopLeft() }

    @objc private func setWidgetSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = DesktopWidgetWindow.Size(rawValue: raw) else { return }
        desktopWidget?.setSize(size)
    }

    @objc private func togglePopoverFromMenu() { togglePopover() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    @objc private func setPlan(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              SessionPlan(rawValue: raw) != nil else { return }
        UserDefaults.standard.set(raw, forKey: "SessionPlan")
        refresh()
    }

    private func showDesktopWidget() {
        if desktopWidget == nil {
            desktopWidget = DesktopWidgetWindow(viewModel: viewModel) { [weak self] action in
                self?.handleWidgetMenuAction(action)
            }
        }
        desktopWidget?.show()
    }

    private func hideDesktopWidget() {
        desktopWidget?.hide()
        desktopWidget = nil
    }

    private func handleWidgetMenuAction(_ action: DesktopWidgetWindow.MenuAction) {
        switch action {
        case .toggleVisibility:
            hideDesktopWidget()
            UserDefaults.standard.set(false, forKey: desktopWidgetEnabledKey)
        case .snapTopLeft:
            desktopWidget?.snapToTopLeft()
        case .setSize(let size):
            desktopWidget?.setSize(size)
        case .openDetails:
            togglePopover()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let report = self.reader.generateReport()
            DispatchQueue.main.async {
                self.viewModel.report = report
                self.updateStatusBar(report)
            }
        }
    }

    private func updateStatusBar(_ r: UsageReport) {
        guard let button = statusItem.button else { return }
        let tokens = r.session.totalTokens
        button.title = " " + Formatter.menuBarCompact(tokens)
        button.toolTip = """
        Aktuelle Sitzung: \(Formatter.full(tokens)) Tokens
        Heute: \(Formatter.full(r.today.totalTokens))
        Woche: \(Formatter.full(r.week.totalTokens))
        Klick für Details
        """
    }

    private func makeTemplateIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 2.5),
                                    xRadius: 3, yRadius: 3)
            NSColor.black.setStroke()
            path.lineWidth = 1.4
            path.stroke()
            let dot = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 6.5, width: 3, height: 3))
            NSColor.black.setFill()
            dot.fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}

// MARK: - Formatter

enum Formatter {
    /// Compact German-style abbreviation for token counts. Decimal comma,
    /// "Mio" for millions, "Tsd" for thousands. Distinct from message-count
    /// abbreviation ("Nachr.") so the two units are never confused.
    static func compact(_ n: Int) -> String {
        let absN = abs(n)
        if absN >= 1_000_000 {
            return String(format: "%.1f Mio", Double(n) / 1_000_000.0)
                .replacingOccurrences(of: ".", with: ",")
        } else if absN >= 1_000 {
            return String(format: "%.1f Tsd", Double(n) / 1_000.0)
                .replacingOccurrences(of: ".", with: ",")
        } else {
            return "\(n)"
        }
    }
    /// Compact form for the menu-bar status item where horizontal space is
    /// extremely tight. Uses single-letter suffix.
    static func menuBarCompact(_ n: Int) -> String {
        let absN = abs(n)
        if absN >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if absN >= 1_000 {
            return String(format: "%.0fk", Double(n) / 1_000.0)
        } else {
            return "\(n)"
        }
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
        nf.maximumFractionDigits = d < 1 ? 4 : 2
        return nf.string(from: NSNumber(value: d)) ?? "$\(d)"
    }
    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let s = Int(date.timeIntervalSince(now))
        let absS = abs(s)
        let prefix = s >= 0 ? "in " : "vor "
        if absS < 60 { return prefix + "\(absS) s" }
        if absS < 3600 { return prefix + "\(absS / 60) min" }
        if absS < 86400 { return prefix + "\(absS / 3600) h \((absS % 3600) / 60) min" }
        return prefix + "\(absS / 86400) d"
    }
    static func clockTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}

// MARK: - View model

final class UsageViewModel: ObservableObject {
    @Published var report: UsageReport?
}
