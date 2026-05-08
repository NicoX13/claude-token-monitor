# Claude Token Monitor

> A native macOS app that surfaces your Claude Code token usage — menu-bar
> item, detail popover, and a desktop widget. Built and maintained by
> **[Nico Felix](https://github.com/NicoX13)**.

[![build](https://github.com/NicoX13/claude-token-monitor/actions/workflows/build.yml/badge.svg)](https://github.com/NicoX13/claude-token-monitor/actions/workflows/build.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000?logo=apple&logoColor=white)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Author: Nico Felix](https://img.shields.io/badge/author-Nico%20Felix-181717?logo=github&logoColor=white)](https://github.com/NicoX13)

Free for everyone to use, fork, modify and ship under the MIT license.

- **Menu-bar item** with live percent of session quota (`✦ 17%`)
- **Detail popover** mirroring claude.ai/usage:
  *Aktuelle Sitzung* + *Wöchentliche Limits* (Alle Modelle, Nur Sonnet, Nur Opus)
- **Desktop widget** (small / medium / large) in the same Anthropic-style
  layout, dark-glass design that fits next to macOS Tahoe widgets
- **Plan presets** (Pro / Max 5× / Max 20×) with sensible default token
  caps you can override via the right-click menu
- **Sub-second updates** when Claude Code writes to a JSONL — no polling
  spam, no stale numbers

All data is read locally from `~/.claude/projects/`. No network. No
telemetry. Builds with the standard Command Line Tools — **no Xcode required**.

---

## Requirements

- macOS 13 or newer
- Apple Silicon (the build script targets `arm64`)
- Claude Code installed and used at least once on this machine, so it has
  written JSONL logs to `~/.claude/projects/`

## Install

### Option A — Pre-built release (recommended, ~30 seconds)

1. Open **[the latest release](https://github.com/NicoX13/claude-token-monitor/releases/latest)**.
2. Download `ClaudeTokenMonitor.zip`.
3. Unzip → drag **Claude Token Monitor.app** into `/Applications`.
4. Right-click the app → **Open** → confirm. (One-time Gatekeeper prompt
   because the app is ad-hoc signed; future launches happen silently.)
5. Look at the top-right of your menu bar. The `✦` icon shows your live
   session-token count. Right-click it for widget controls.

That's it — there's nothing to configure.

### Option B — Build from source

Needs Apple's Command Line Tools (no full Xcode):

```bash
xcode-select --install
git clone https://github.com/NicoX13/claude-token-monitor.git
cd claude-token-monitor
./install.sh
```

`install.sh` builds, copies to `/Applications`, launches, and asks whether
to register a Login Item.

### Where do the numbers come from?

The app does **not** call any API. It reads your own Claude Code session
logs at `~/.claude/projects/<project>/<session-uuid>.jsonl`. Every assistant
response logged there contains a `usage` object with `input_tokens`,
`output_tokens`, `cache_creation_input_tokens`, and `cache_read_input_tokens`.
The app deduplicates via `message.id` and aggregates into:

- the current **5-h session** window (matches Anthropic's rate-limit clock),
- the current **week** since the last Mon 06:00 reset,
- with separate Sonnet / Opus filters for the weekly view.

**Nothing leaves your machine.** If the popover shows zeros, you simply
haven't run Claude Code yet on this Mac — fire one prompt and it'll show
up within ~1 second (a `DispatchSource` watcher reacts to file writes).

#### Important caveat — what the app does *not* see

Claude Code writes to `~/.claude/projects`, but **claude.ai (web)**,
**Claude Desktop**, and **mobile apps** do not. If you also chat there,
their tokens are absent from this widget's numbers. So:

- "Alle Modelle" and the percentage may run a bit *behind* claude.ai's
  dashboard.
- "Nur Sonnet" / "Nur Opus" reflect *only* what you used through Claude
  Code locally. If you start a Sonnet conversation in the web app, the
  widget keeps showing 0 % Sonnet.

The exact, authoritative numbers always live at
[claude.ai/usage](https://claude.ai/usage). The widget aims to be a
fast at-a-glance approximation for the Claude-Code-first workflow.

### Update

```bash
cd claude-token-monitor && git pull && ./install.sh
```

…or just download the newest zip from the Releases page and replace the
app in `/Applications`.

### Uninstall

```bash
pkill -x ClaudeTokenMonitor
rm -rf "/Applications/Claude Token Monitor.app"
defaults delete local.claudetokenmonitor 2>/dev/null
osascript -e 'tell application "System Events" to delete login item "Claude Token Monitor"' 2>/dev/null
```

## Usage

**Menu-bar item (`✦ 17%`):**
- Left-click → detail popover.
- Right-click → status menu:
  *Widget toggle*, *snap*, *size*, **plan**, **Jetzt aktualisieren**,
  **Bei Login starten**, *Details*, *Beenden*.
- Hover → tooltip with session % and the three weekly rows at a glance.

**Plan submenu (right-click → Plan):**
- *Pro* / *Max 5×* / *Max 20×* — sets the token caps used for the
  percentage display. Default is **Max 5×**.
- *Prozent-Anzeige aus* — falls back to raw token counts everywhere.

**"Jetzt aktualisieren":** force-refresh that drops every cached parse
result, rebuilds the file-system watcher, restarts the polling timer,
and re-reads JSONL from disk. Useful if you ever suspect numbers are
stale. The popover footer shows "Aktualisiert vor X s" so you can spot
a stuck pipeline at a glance.

**"Bei Login starten":** toggle that registers the app as a Login Item
via `SMAppService` (no installer needed). Persists across reboots.

**Desktop widget:**
- Three sizes via right-click → Größe (klein / mittel / groß).
- Click-and-drag the dark surface to reposition. Position persists.
- Right-click on the widget → same context menu as the status item.
- Appears on every Space, never steals focus, sits on the desktop layer
  (above wallpaper, below app windows).

## Resilience — sleep / wake / restart / Claude closed

The app is engineered to survive every common interruption:

| Event | Behaviour |
|---|---|
| **Mac sleeps and wakes** (overnight, lid close) | On `NSWorkspace.didWakeNotification` the file-system watcher AND the polling timer are torn down and rebuilt, then `refresh()` runs. Long-sleep stale state cannot persist. |
| **Mac restarts** | If the Login Item toggle is on, the app launches automatically at the next login and resumes monitoring. Toggle is in the right-click menu. |
| **Claude Code closed** | The widget keeps showing the most recent state (no new JSONL writes = nothing to update). When Claude Code starts again, the file-system watcher fires within ~1 s of the next assistant response. |
| **Day rollover (00:00)** | `NSCalendarDayChanged` and `NSSystemClockDidChange` observers trigger an immediate refresh so "Today" / "this week" buckets slide correctly. |
| **App Nap** | Disabled at launch with `ProcessInfo.beginActivity(.userInitiated)`. macOS will not throttle this background-only app while you're using your Mac. |
| **Watcher dies silently** | "Jetzt aktualisieren" in the right-click menu is a heavy-handed manual rebuild that forces every layer to be reconstructed from scratch. The popover's "Aktualisiert vor X s" footer surfaces the issue. |

## Plan calibration

Anthropic doesn't publish hard token caps for the Pro / Max tiers, so the
percentage shown is an *approximation*. The defaults were calibrated
against Max-5× dashboard samples (May 2026):

|              | session (5h)   | week — all models | week — Sonnet     | week — Opus   |
|--------------|---------------:|-------------------:|-------------------:|---------------:|
| Pro          | 66 M           | 400 M              | 1 Mrd              | 100 M         |
| **Max 5×** *(default)* | 330 M     | 2 Mrd              | 5 Mrd              | 500 M         |
| Max 20×      | 1.32 Mrd       | 8 Mrd              | 20 Mrd             | 2 Mrd         |

These caps live in [`Sources/Models.swift`](Sources/Models.swift) — easy
to tweak if Anthropic changes the math. **The exact, authoritative
numbers are always at [claude.ai/usage](https://claude.ai/usage).**

## Security

No network. No code execution from JSONL data. Hardened parser with
allow-list sanitisation, token/timestamp clamping, symlink rejection,
path-traversal guard, and size/line-count caps. SwiftUI never parses
external strings as `LocalizedStringKey` / markdown. Full audit in
[SECURITY.md](SECURITY.md).

To report a security finding: [GitHub Security Advisories](https://github.com/NicoX13/claude-token-monitor/security/advisories/new)
or email [info@x-fingers.com](mailto:info@x-fingers.com).

## About the author

Built and maintained by **Nico Felix** —
[@NicoX13 on GitHub](https://github.com/NicoX13).

📬 **Contact:** [info@x-fingers.com](mailto:info@x-fingers.com) — for
collaboration, hire, press, or anything that isn't a bug or feature
request.

If this project saves you time:
- ⭐ Star the repo
- 🐛 [Open an issue](https://github.com/NicoX13/claude-token-monitor/issues/new/choose) for bugs or feature ideas
- 🔧 [Send a PR](CONTRIBUTING.md) for fixes or improvements

## License

[MIT License](LICENSE) — © 2026 Nico Felix.

You are free to use, copy, modify, distribute, sublicense, and sell copies
of this software, as long as the copyright notice and license stay with
the source.

This project is unaffiliated with Anthropic. Claude™ is a trademark of
Anthropic.
