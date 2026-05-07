# Claude Token Monitor

> A native macOS app that surfaces your Claude Code token usage everywhere
> you'd want to see it — menu-bar item, detail popover, and a real desktop
> widget. Built and maintained by **[Nico Felix](https://github.com/NicoX13)**.

[![build](https://github.com/NicoX13/claude-token-monitor/actions/workflows/build.yml/badge.svg)](https://github.com/NicoX13/claude-token-monitor/actions/workflows/build.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000?logo=apple&logoColor=white)](#requirements)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-F05138?logo=swift&logoColor=white)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![No Xcode required](https://img.shields.io/badge/build-no%20Xcode-success)](#build)
[![Author: Nico Felix](https://img.shields.io/badge/author-Nico%20Felix-181717?logo=github&logoColor=white)](https://github.com/NicoX13)

Free for everyone to use, fork, and modify under the MIT license — see
[About the author](#about-the-author) at the bottom.

A native macOS app that surfaces your **Claude Code** token usage everywhere
you'd want to see it:

- **Menu-bar item** with a live token counter
- **Detail popover** with session / today / week / month / all-time stats
- **Desktop widget** (small / medium / large) styled like macOS Tahoe widgets

All data is read locally from `~/.claude/projects/**/*.jsonl`. No network. No
telemetry. Builds with the standard Command Line Tools — **no Xcode required**.

```
✦ 1.9k     ← in your menu bar, always visible

┌────────────────────────────┐
│ ✦ Session                  │
│                            │
│ 1.951.652  Tokens · Session│
│ ━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ Reset 11:46                │
│                            │
│ Heute    1,9 M    $8,78    │
│ Woche    5,8 M   $18,22    │
│ Monat    5,8 M   $18,22    │
│ Gesamt  16,1 M   $19,74    │
└────────────────────────────┘   ← desktop widget on the left
```

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [How it works](#how-it-works)
- [Pricing](#pricing)
- [Security](#security)
- [Build from source](#build)
- [Project layout](#project-layout)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

| Surface | What you see |
|---|---|
| Menu bar (top right) | Compact token count `✦ 1.9k`, live tooltip, click → popover, right-click → menu |
| Popover | Session counter with 5-h reset progress, today/week/month/all-time, in/out/cache-write/cache-read chips, top 5 models, last activity |
| Desktop widget (left) | Three sizes (small/medium/large), dark glass design, drag-to-place, position-persistent, on the desktop layer (above wallpaper, below app windows) |

The desktop widget is **not** a true WidgetKit extension — see
[Limitations](#limitations) for why. Visually and ergonomically it's
indistinguishable from one.

## Requirements

- macOS 13 or newer (tested on 26.3.1)
- Apple Silicon (the build script targets `arm64`; trivial to add `x86_64`)
- Command Line Tools for Xcode (`xcode-select --install`)
- An active Claude Code installation that writes JSONL logs to `~/.claude/projects`

## Install

You have two paths: download a pre-built `.app` from the latest release
(fastest, no toolchain needed), or build from source (gives you the audited
code in your hands).

### Option A — Pre-built release (recommended)

1. Open the latest release page:
   **https://github.com/NicoX13/claude-token-monitor/releases/latest**
2. Download `ClaudeTokenMonitor.zip`.
3. Double-click the zip → drag **Claude Token Monitor.app** into your
   `/Applications` folder.
4. Right-click the app → **Open** → confirm in the Gatekeeper dialog.
   (You only need to do this the very first time, because the app is
   ad-hoc signed — see the [Gatekeeper note](#gatekeeper-on-first-launch)
   below.)
5. Look at the top-right of your menu bar. You'll see the `✦` icon with
   your live token count. Right-click it for widget controls.

That's it. The app reads your local Claude Code logs at `~/.claude/projects/`
— there's nothing to configure.

### Option B — Build from source

You need the **Command Line Tools for Xcode** (no full Xcode required):

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/NicoX13/claude-token-monitor.git
cd claude-token-monitor
./install.sh
```

`install.sh` does four things:
1. Builds `Claude Token Monitor.app` from source (~5 seconds via `swiftc`).
2. Copies it to `/Applications/Claude Token Monitor.app`.
3. Launches it.
4. Asks whether to register a Login Item so it starts automatically every
   time you log in (you can also do this later in *System Settings → General
   → Login Items*).

If you only want to build and try it without installing system-wide:

```bash
./build.sh
open ".build/Claude Token Monitor.app"
```

### Where do the numbers come from?

The app does **not** call any API — it reads your own Claude Code session
logs directly from your home folder:

```
~/.claude/projects/<project-name>/<session-uuid>.jsonl
```

Every assistant response that Claude Code logs there contains a `usage`
object with `input_tokens`, `output_tokens`, `cache_creation_input_tokens`
and `cache_read_input_tokens`. The app deduplicates via `message.id`,
buckets the data into session / today / week / month / all-time, and
displays it. **Nothing leaves your machine.**

If the popover shows zero tokens: that just means you haven't used Claude
Code yet on this Mac, or `~/.claude/projects` is empty. Fire one Claude
Code prompt and the next 30-second refresh tick will pick it up.

### Gatekeeper on first launch

The app is **ad-hoc signed** — no Apple Developer ID, no notarisation.
Apple's Gatekeeper will warn the first time you launch it that it's "from
an unidentified developer". Two options:

- Right-click the app icon → **Open** → confirm in the dialog, or
- *System Settings → Privacy & Security* → **Allow anyway** for
  Claude Token Monitor.

After this one-time confirmation, future launches happen silently.

### Updating

```bash
cd claude-token-monitor
git pull
./install.sh
```

Or just download the newest `ClaudeTokenMonitor.zip` from the releases page
and replace the app in `/Applications`.

### Uninstall

```bash
pkill -x ClaudeTokenMonitor
rm -rf "/Applications/Claude Token Monitor.app"
defaults delete local.claudetokenmonitor 2>/dev/null
osascript -e 'tell application "System Events" to delete login item "Claude Token Monitor"' 2>/dev/null
```

The app keeps no other state on disk — no caches, no databases, no
network preferences.

## Usage

### Menu-bar item

| Action | What happens |
|---|---|
| Left-click | Open detail popover |
| Right-click / Ctrl-click | Status menu |
| Hover | Tooltip with quick session/today/week numbers |

### Status menu (right-click)

- **Show / hide desktop widget**
- **Pin widget to top-left** (snap to standard position)
- **Widget size** → Small / Medium / Large
- **Open details** (= popover)
- **Quit**

### Desktop widget

- **Click-and-drag** the dark surface to reposition.
- Position persists across launches.
- Appears on every Space (`canJoinAllSpaces`).
- Never steals focus.
- Visible whenever no app window is in front of it (use ⌘-F3 to peek the desktop).

## How it works

```
~/.claude/projects/<project>/<session-uuid>.jsonl
                    │
                    ▼
            UsageReader (Swift)
            ─ allow-list sanitisation
            ─ token / timestamp clamping
            ─ symlink + path-traversal guards
            ─ size and line-count limits
            ─ message.id deduplication
            ─ size-+-mtime file cache
                    │
                    ▼
        rolling-5-h session detection
        today / week / month / all-time buckets
        per-model breakdown
                    │
                    ▼
   ┌────────────────┼─────────────────┐
   ▼                ▼                 ▼
Status item    Popover (SwiftUI)   Desktop widget
                                   (NSWindow on
                                    desktop level)
```

A 30-second background timer regenerates the report; SwiftUI updates the live
countdown every second.

## Pricing

Tariffs in [`Sources/Pricing.swift`](Sources/Pricing.swift) are easy to edit:

| Family   | input | output | cache read | cache write 5 m | cache write 1 h |
|----------|------:|-------:|-----------:|----------------:|----------------:|
| Opus 4.x | $15   | $75    | $1.50      | $18.75          | $30             |
| Sonnet 4.x | $3  | $15    | $0.30      | $3.75           | $6              |
| Haiku 4.x | $1   | $5     | $0.10      | $1.25           | $2              |

Costs are **API-equivalent estimates**. If you're on Pro or Max you pay your
flat subscription — the dollar number is just "this is what it would have cost
on metered API pricing."

## Security

Full self-audit and threat model: [SECURITY.md](SECURITY.md).

Highlights:
- **No network.** No `URLSession`, no telemetry.
- **No code execution from data.** No `Process`, `system`, `eval`, `WebView`.
- **Hardened parser.** Allow-list sanitisation, token/timestamp clamping,
  symlink rejection, path-traversal guard, size/line-count caps.
- **`Text(verbatim:)`** for every UI string derived from JSONL → SwiftUI never
  parses external data as `LocalizedStringKey` / markdown.
- **No prompt-injection vector.** The app never feeds JSONL content to any
  LLM and never renders it as a clickable link.

## Build

The build script uses **only** `swiftc` from Command Line Tools — no Xcode,
no SwiftPM:

```bash
./build.sh
```

It produces `.build/Claude Token Monitor.app` with:
- the host binary at `Contents/MacOS/ClaudeTokenMonitor`
- ad-hoc code signature
- `Info.plist` with `LSUIElement = true` (no Dock icon)

GitHub Actions build the same target on every push and on tagged releases:
[`.github/workflows/build.yml`](.github/workflows/build.yml).

## Project layout

```
claude-token-monitor/
├── Sources/
│   ├── Models.swift              # UsageEntry, UsageBucket, UsageReport
│   ├── Pricing.swift             # Pricing table + cost calculation
│   ├── UsageReader.swift         # JSONL parser, caching, aggregation, hardening
│   ├── DesktopWidgetWindow.swift # Borderless desktop-level NSWindow
│   ├── AppDelegate.swift         # NSStatusItem + right-click menu
│   ├── PopoverView.swift         # SwiftUI popover
│   ├── main.swift                # NSApplication entry point
│   └── Widget/                   # WidgetKit extension (needs Apple Developer ID)
├── Resources/
│   ├── Info.plist                # Host bundle metadata
│   └── Widget/Info.plist         # Extension metadata (for future Dev-ID build)
├── .github/
│   ├── workflows/build.yml       # CI build + release packaging
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── build.sh                      # Builds .app — no Xcode required
├── install.sh                    # Copies to /Applications + Login Item
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE
└── README.md
```

## Limitations

### Why isn't this a "real" Notification-Center widget?

A native WidgetKit extension would require the parent app to be signed with an
**Apple Developer ID** (paid, $99/year) or notarised. Ad-hoc-signed widget
extensions are rejected by AMFI:

```
amfid: not valid: AppleMobileFileIntegrityError Code=-423
"The file is adhoc signed or signed by an unknown certificate chain"
```

The desktop-widget *NSWindow* sidesteps this restriction while delivering the
same visual and the same ergonomics (it's draggable, lives on the desktop, and
the user can never accidentally close it).

The `Sources/Widget/*` code is fully functional and ready to ship — it just
needs a signed parent app to be loadable. PRs from anyone with a Developer ID
are welcome.

### Other notes

- Pricing data is a snapshot in time — update `Pricing.swift` if Anthropic's
  rates change.
- The session detector assumes a 5-hour rolling window matching Claude
  Pro/Max's quota cadence.
- Currently localised to German for the UI strings; English fallback is
  present in code comments.

## Roadmap

- [ ] WidgetKit extension shipped under a Developer ID (PRs welcome)
- [ ] Apple Watch complication powered by the same data
- [ ] 7-day spark-line in the popover
- [ ] CSV export of the all-time bucket
- [ ] Threshold alerts (notification when X % of session quota used)

See [open issues](https://github.com/NicoX13/claude-token-monitor/issues) and
[contributing guidelines](CONTRIBUTING.md).

## About the author

Built and maintained by **Nico Felix** —
[@NicoX13 on GitHub](https://github.com/NicoX13).

📬 **Contact:** [info@x-fingers.com](mailto:info@x-fingers.com)

If this project saves you time, the kindest things you can do are:
- ⭐ Star the repo so others find it
- 🐦 Share it with anyone running Claude Code
- 🐛 Open an issue if something breaks
- 🔧 Send a PR if you have a fix or improvement (see [CONTRIBUTING](CONTRIBUTING.md))

### When to use which channel

| Situation | Channel |
|---|---|
| 🐛 Bug or regression | [Open an issue](https://github.com/NicoX13/claude-token-monitor/issues/new/choose) |
| 💡 Feature idea | [Open an issue](https://github.com/NicoX13/claude-token-monitor/issues/new/choose) |
| 🔒 Security finding | [GitHub Security Advisories](https://github.com/NicoX13/claude-token-monitor/security/advisories/new) — *please not a public issue* |
| 📨 Anything else (collaboration, hire, press, questions) | [info@x-fingers.com](mailto:info@x-fingers.com) |

## License

Released under the [MIT License](LICENSE) — © 2026 Nico Felix.

You are free to **use**, **copy**, **modify**, **merge**, **publish**,
**distribute**, **sublicense**, and **sell** copies of this software, as long
as the copyright notice and license stay with the source. No warranty.

This project is unaffiliated with Anthropic. Claude™ is a trademark of
Anthropic.
