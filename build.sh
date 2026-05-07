#!/usr/bin/env bash
# Build "Claude Token Monitor.app" using only the Swift compiler from
# Command Line Tools. No Xcode required.
#
# Note: Sources/Widget/* contains a WidgetKit extension that *would* render in
# the macOS Notification Center / desktop widget gallery, but AMFI rejects
# ad-hoc-signed widget extensions. Without an Apple Developer ID we approximate
# the same visual via a desktop-level NSWindow (DesktopWidgetWindow.swift).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Claude Token Monitor"
BIN_NAME="ClaudeTokenMonitor"
BUILD_DIR=".build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "==> Compiling host app…"
swiftc \
    -O \
    -target arm64-apple-macos13 \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -o "${MACOS_DIR}/${BIN_NAME}" \
    Sources/Models.swift \
    Sources/Pricing.swift \
    Sources/UsageReader.swift \
    Sources/DesktopWidgetWindow.swift \
    Sources/AppDelegate.swift \
    Sources/PopoverView.swift \
    Sources/main.swift

cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

echo "==> Code-signing (ad-hoc)…"
codesign --force --deep --sign - --timestamp=none \
    "${APP_DIR}" >/dev/null 2>&1 || true

echo
echo "Built: ${APP_DIR}"
echo "Run:   open \"${APP_DIR}\""
