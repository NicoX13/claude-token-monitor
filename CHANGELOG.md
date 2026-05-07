# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Right-click context menu on the desktop widget itself (toggle / snap /
  size / open details / quit). Previously these were only reachable from
  the menu-bar status item.

### Fixed
- Hard outline around the desktop widget caused by AppKit's window shadow
  tracing the alpha edge of the rounded SwiftUI content. Disabled
  `NSWindow.hasShadow` and rely solely on the soft SwiftUI drop shadow.
- Removed the redundant white 1-pt overlay stroke that contributed to the
  visible border.

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
