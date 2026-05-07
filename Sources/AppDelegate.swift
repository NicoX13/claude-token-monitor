import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var refreshTimer: Timer?
    private let reader = UsageReader()
    private let viewModel = UsageViewModel()
    private var desktopWidget: DesktopWidgetWindow?
    private let desktopWidgetEnabledKey = "DesktopWidgetEnabled"

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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30,
                                            repeats: true) { [weak self] _ in
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
        button.title = " " + Formatter.compact(tokens)
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
    static func compact(_ n: Int) -> String {
        let absN = abs(n)
        if absN >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        } else if absN >= 1_000 {
            return String(format: "%.1fk", Double(n) / 1_000.0)
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
