#!/usr/bin/env bash
# Install "Claude Token Monitor.app" to /Applications and (optionally) add it
# to Login Items so it starts every time you log in.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Claude Token Monitor"
SRC_APP=".build/${APP_NAME}.app"
DEST_APP="/Applications/${APP_NAME}.app"

if [[ ! -d "${SRC_APP}" ]]; then
    echo "==> Bundle missing — running build.sh first"
    ./build.sh
fi

echo "==> Installing to /Applications"
# Always quit the running instance (if any) before touching the bundle. macOS
# keeps the old binary mmap'd; overwriting the file in /Applications without
# killing the process leaves it executing the old code until a manual restart.
pkill -x "ClaudeTokenMonitor" 2>/dev/null || true
# Wait until it's actually gone (max 5 s), so the cp below can't race the
# still-shutting-down process.
for _ in 1 2 3 4 5; do
    pgrep -x "ClaudeTokenMonitor" >/dev/null 2>&1 || break
    sleep 1
done

if [[ -d "${DEST_APP}" ]]; then
    rm -rf "${DEST_APP}"
fi
cp -R "${SRC_APP}" "${DEST_APP}"

echo "==> Launching"
open "${DEST_APP}"

echo
echo "Installed: ${DEST_APP}"
echo
read -r -p "Soll die App bei jedem Login automatisch starten? [j/N] " ans
case "${ans}" in
    j|J|y|Y|ja|JA|Ja)
        osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Claude Token Monitor.app", hidden:true}' >/dev/null
        echo "==> Login Item hinzugefügt."
        ;;
    *)
        echo "==> Übersprungen. Du kannst es später unter Einstellungen → Allgemein → Anmeldeobjekte hinzufügen."
        ;;
esac

echo
echo "Fertig. Schau oben rechts in die Menüleiste."
