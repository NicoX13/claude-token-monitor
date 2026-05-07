# Claude Token Monitor

> A native macOS app that surfaces your Claude Code token usage — menu-bar
> item, detail popover, and a desktop widget. Built and maintained by
> **[Nico Felix](https://github.com/NicoX13)**.

[![build](https://github.com/NicoX13/claude-token-monitor/actions/workflows/build.yml/badge.svg)](https://github.com/NicoX13/claude-token-monitor/actions/workflows/build.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000?logo=apple&logoColor=white)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Author: Nico Felix](https://img.shields.io/badge/author-Nico%20Felix-181717?logo=github&logoColor=white)](https://github.com/NicoX13)

Free for everyone to use, fork, modify and ship under the MIT license.

- **Menu-bar item** with a live token counter
- **Detail popover** with session / today / week / month / all-time stats
- **Desktop widget** (small / medium / large) styled like macOS Tahoe widgets

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
The app deduplicates via `message.id` and aggregates into session / today /
week / month / all-time buckets. **Nothing leaves your machine.**

If the popover shows zeros, you simply haven't run Claude Code yet on this
Mac — fire one prompt and it'll show up within 30 seconds.

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

**Menu-bar item:**
- Left-click → detail popover.
- Right-click → status menu (toggle widget, snap, change size, quit).
- Hover → quick session/today/week tooltip.

**Desktop widget:**
- Click-and-drag the dark surface to reposition. Position persists.
- Right-click on the widget → same context menu as the status item.
- Appears on every Space, never steals focus, sits on the desktop layer
  (above wallpaper, below app windows).

## Pricing model

Cost numbers are API-equivalent estimates (Opus / Sonnet / Haiku 4.x). If
you're on Pro or Max you pay your flat subscription — the dollar number is
just "this is what it would cost on metered API pricing." Tariffs live in
[`Sources/Pricing.swift`](Sources/Pricing.swift) and are easy to update.

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
