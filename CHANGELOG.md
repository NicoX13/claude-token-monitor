# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.2] — 2026-05-07

### Fixed
- **Progress bars in the desktop widget were nearly invisible.** macOS's
  `ProgressView` renders a ~4 pt-tall track by default, and we'd shrunk it
  further with `.scaleEffect(y: 0.55–0.8)` to fit each row, leaving 2–3 px
  of bar that disappeared into the dark widget background. Replaced with a
  custom `WBar` (Capsule + fill) at fixed 4–6 pt heights that stay
  readable at 100 % opacity. Affects all widget sizes; the popover still
  uses the standard `ProgressView` because its higher contrast and slightly
  larger track work fine on the system background.

## [1.4.1] — 2026-05-07

### Fixed
- **Large desktop widget: missing subtitle on the "Nur Opus" row.**
  In 1.4.0 only the *Alle Modelle* row showed the
  "Zurücksetzung Mo., 06:00" hint, the other two rows had no
  subtitle when the bucket was non-empty. The Opus row in particular
  ended up with the label and percent floating with no caption,
  which looked broken next to the consistently-captioned popover.
  The widget now always renders a subtitle — either the
  "diese Woche nicht genutzt" fallback when the bucket is empty,
  or the reset hint otherwise — matching the popover layout.

## [1.4.0] — 2026-05-07

### Added
- **Desktop widget now mirrors the Anthropic dashboard layout.** The
  weekly limits introduced for the popover in 1.3.0 are now also
  surfaced in the medium and large widget sizes:
    - **Medium (348 × 165):** session percent on the left, three
      weekly rows ("Alle Modelle", "Nur Sonnet", "Nur Opus") with
      mini progress bars on the right, plus a "Reset Mo., 06:00"
      footnote.
    - **Large (348 × 348):** full Anthropic-style "Wöchentliche
      Limits" section under the session block, each row with its
      own percent indicator and progress bar.
- **Status-item now shows percent.** The menu-bar headline switched
  from compact tokens (`✦ 52,5M`) to plan percentage (`✦ 17%`) so
  it matches the rest of the UI. Falls back to the compact token
  count when the user has chosen "Prozent-Anzeige aus".
- **Status-item tooltip mirrors the Anthropic dashboard.** Hovering
  the menu-bar item shows session %, plus the three weekly rows
  (Alle Modelle / Nur Sonnet / Nur Opus) at a glance — no click
  needed for a quick check.

### Changed
- Small widget keeps its existing percent-only design — it has too
  little room for the weekly breakdown. Use medium or large for the
  full panel.

## [1.3.0] — 2026-05-07

### Added
- **Anthropic-style "Plan-Nutzungslimits" panel.** The popover now
  mirrors the layout of claude.ai/usage:
    1. **Aktuelle Sitzung** with `XX % verwendet` and
       "Zurücksetzung in Y Std. Z Min." copy.
    2. **Wöchentliche Limits** with three rows:
       - *Alle Modelle* — total tokens between Mon 06:00 resets.
       - *Nur Sonnet* — Sonnet-only filter.
       - *Nur Opus* — Opus-only filter.
       Each row gets its own `XX % verwendet` indicator and an
       Anthropic-style "Zurücksetzung Mo., 06:00" label.
- Weekly window now resets at **Monday 06:00 local time** (was
  Monday 00:00), matching the dashboard's actual rollover.
- `weeklyAllLimit` / `weeklySonnetLimit` / `weeklyOpusLimit` per
  plan tier in `SessionPlan`. Calibrated against a Max 5× sample
  showing 6 % at ~100 M total weekly tokens → ~1.7 Mrd cap.

### Changed
- Removed the per-period "Heute / Woche / Monat / Gesamt" grid
  from the popover — the new weekly-limits section is the better
  signal for "am I close to my cap?" and the historical totals
  added clutter without being actionable.
- Removed the per-model "Top 5" breakdown from the popover for
  the same reason. (Per-model figures are still visible via the
  Sonnet / Opus rows.)

### Note on "Claude Design"
The Anthropic dashboard shows a third weekly row labelled
"Claude Design". From the user's data we determined this is a
separate Anthropic *feature* (likely Artifacts / canvas tooling),
not a model family — a user with 100 % Opus traffic still sees
"Claude Design: noch nicht genutzt". We render the row as
"Nur Opus" instead, which is what the local JSONL data
actually supports. The percentage on that row may not match
the dashboard exactly because Anthropic's pool sharing between
Sonnet and Opus is not visible from outside the API.

## [1.2.0] — 2026-05-07

### Changed
- **Hero number switched from raw tokens to percent.** Anthropic's own
  "Plan-Nutzungslimits" page on claude.ai shows `13 % verwendet`, which
  is much easier to read at a glance than `43.096.892 / 5,0 Mio`.
  The popover and all three widget sizes now show the percent
  prominently with the token + message counts as a small secondary
  line. The progress bar mirrors the percent.
- **Plan token limits recalibrated.** A user on Max 5× sent us a
  screenshot showing 13 % consumed at 43 M reported tokens, which
  implies a 100 % point at ~330 M. New defaults:
    - Pro:    66 M (was 250 k — off by ~260×)
    - Max 5×: 330 M (was 1 M — off by ~330×)
    - Max 20×: 1.32 Mrd (was 5 M — off by ~260×)
  These are still approximations because Anthropic doesn't publish
  exact caps, but the percentage now closely matches what claude.ai
  shows. The "Plan" submenu copy is shorter (just "Pro" / "Max 5×"
  / "Max 20×" / "Prozent-Anzeige aus") since the absolute numbers
  are no longer the headline.
- **Default plan is now Max 5×** (was Max 20×). Most current Claude
  Code subscribers are on Max 5×; users on a different plan can
  still flip via the right-click menu.

### Fixed
- "Limit ausblenden" mode now falls back to the raw token count
  (and the time-elapsed progress bar) instead of leaving the
  progress bar empty.

### Fixed
- **Session detection now uses Anthropic-style fixed 5-h windows.** The
  previous heuristic looked for the longest contiguous run of messages
  with no >5 h gap and treated that as "the current session". For users
  who chat for more than five straight hours, that bundled multiple
  real Anthropic sessions into a single inflated bucket — the screen
  in 1.1.1 showed *all* of today's tokens (74 M / 286 messages) as the
  active session, with the reset clock pinned at the original session's
  end (already 48 min in the past). The new algorithm walks messages
  chronologically and starts a new 5-h window whenever a prompt arrives
  at or after the previous window's end, mirroring how Anthropic's
  quota system actually counts.
- "Sitzung abgelaufen" state is now displayed honestly instead of
  showing a pinned-at-zero countdown. When `now` is past the most
  recent session's end, the popover and widget say "Letzte Sitzung
  (abgelaufen) — Beendet vor X min, wartet auf nächsten Prompt"
  rather than counting down at 0 h 00 min indefinitely.

### Changed
- **Unified abbreviations.** Token compact suffix changed from `M` /
  `k` to `Mio` / `Tsd` (German), and message-count suffix changed
  from `Msgs` to `Nachr.` so the two units can never be confused
  visually. Menu-bar item still uses single-letter `M` / `k` because
  it has only a few pixels of width.

### Added
- Most-recent-session view shows the message count as `N Nachr.` next
  to the token total, matching the per-period rows.

### Changed
- Polling fallback interval relaxed from 5 s to **60 s**. The
  `DispatchSource` file-system watcher already triggers a refresh
  within ~1 s of any Claude Code write, so frequent polling was
  unnecessary CPU/IO. The 60 s timer now only acts as a safety net for
  edge cases where the watcher might miss an event (network mounts,
  sleep/wake races).

### Fixed
- `install.sh` now always kills the running `ClaudeTokenMonitor`
  process before overwriting the bundle, even when the destination
  doesn't exist yet. Previously the script only killed when
  `/Applications/Claude Token Monitor.app` was already present, so a
  manual `cp -R` over a running app would leave the process executing
  the *old* in-memory binary until the user restarted it manually —
  exactly the symptom that made v1.1.0 feel broken on first launch
  for some users.

## [1.1.0] — 2026-05-07

### Added
- **Plan-based session quota display.** A new "Plan" submenu in the
  status-item right-click menu lets users pick Pro (~250k), Max 5×
  (~1M), Max 20× (~5M), or "Limit ausblenden". When a plan is set, the
  popover and desktop widget show "X / Y Tokens" with a quota progress
  bar. The bar turns orange above 85 % to signal the user is near the
  cap. Defaults to Max 20× because most current Claude Code users are
  on Max-tier subscriptions.
- Per-period **message counts** in the popover and widget grids
  ("Heute: 1.9M Tokens · 28 Msgs"). Useful to spot which periods had
  many small messages versus few heavy ones.
- Right-click context menu on the desktop widget itself (toggle / snap /
  size / open details / quit). Previously these were only reachable from
  the menu-bar status item.
- Four-layer refresh strategy: 5-second polling on RunLoop.main `.common`
  mode (replaces 30 s `.default`-mode timer), `DispatchSource`
  file-system watcher on `~/.claude/projects/` for sub-second updates
  on Claude Code writes, plus `NSWorkspace.didWakeNotification` and
  `NSApplication.didBecomeActiveNotification` handlers so timers don't
  drift across sleep/wake.

### Changed
- **Removed all USD cost displays** from the popover and desktop widget.
  Pro and Max subscribers pay a flat fee — the dollar number was only an
  API-equivalent estimate and confused more than it helped. Replaced
  with token counts and message counts.

### Fixed
- Hard outline around the desktop widget caused by AppKit's window shadow
  tracing the alpha edge of the rounded SwiftUI content. Disabled
  `NSWindow.hasShadow` and rely solely on the soft SwiftUI drop shadow.
- Removed the redundant white 1-pt overlay stroke that contributed to the
  visible border.
- Status item and widget would occasionally stay stale up to 30 s when
  the user had a menu open during a refresh tick — `.common` runloop
  mode plus the FS watcher fix this.

## [1.0.0] — 2026-05-07

Initial public release.

### Added
- **Menu bar status item** with live token count (compact format, e.g. `✦ 1.9k`).
- **Detail popover** with current session, today / week / month / all-time buckets,
  per-token-type chips, model breakdown, last activity.
- **Desktop widget window** in three sizes (small, medium, large) — borderless,
  rounded, dark-glass design that mimics the macOS Tahoe widget look.
- **Right-click status menu** to toggle / snap / resize the desktop widget,
  open details, or quit.
- **Live JSONL parser** that walks `~/.claude/projects/**/*.jsonl`, deduplicates
  via `message.id`, and aggregates 5-hour rolling sessions automatically.
- **Cost estimation** with per-model pricing tables (Opus/Sonnet/Haiku 4.x).
- **Hardened parser** with allow-list identifier sanitisation, token caps,
  timestamp validation, file-size / line-count limits, symlink rejection,
  path-traversal guard.
- **WidgetKit extension code** under `Sources/Widget/` — ready to ship the day
  an Apple Developer ID is available.
- **Build script** that produces a complete `.app` bundle using only Command
  Line Tools (no Xcode required).
- **Install script** with automatic Login Item registration.
- **MIT license**.

### Security
- Full self-audit documented in `SECURITY.md`.
- No network requests, no external code execution from JSONL data,
  no markdown rendering of user-controlled strings.

### Known limitations
- Ad-hoc signed only — macOS shows a Gatekeeper warning on first launch.
  Use right-click → Open the first time, or sign with an Apple Developer ID.
- AMFI rejects ad-hoc-signed widget extensions, so the desktop widget is
  approximated by an `NSWindow` on the desktop layer rather than a true
  WidgetKit extension. The extension code is included for future use with
  a Developer ID.
