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
if [[ -d "${DEST_APP}" ]]; then
    # Quit the existing copy so we can overwrite it. Match by exact basename
    # of the binary so we never kill something unrelated.
    pkill -x "ClaudeTokenMonitor" 2>/dev/null || true
    sleep 1
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
