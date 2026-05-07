# Security

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security-related findings.
Use one of the following channels instead:

1. **Preferred — GitHub Security Advisories (private):**
   https://github.com/NicoX13/claude-token-monitor/security/advisories/new
2. **Email:** `info@x-fingers.com` — please include "claude-token-monitor security" in the subject so it gets routed correctly.

You will get a response within a few days. We commit to crediting reporters in
the release notes (unless you prefer to stay anonymous).

## Supported versions

| Version  | Supported          |
|----------|--------------------|
| 1.x      | ✅ active          |
| < 1.0    | —                  |

---

# Security Audit — Claude Token Monitor

Audit-Datum: 2026-05-07
Audit durch: Selbstreview vor Release

## Bedrohungsmodell

Der einzige Datenfluss ist:

```
~/.claude/projects/**/*.jsonl   →   UsageReader   →   SwiftUI-Popover
       (potenziell angreifer-                    (rein lesend, lokal,
        gesteuerter Inhalt)                      kein Netzwerk)
```

Die JSONL-Logs enthalten u. a. User-Prompts und Tool-Outputs aus dem Web — also Daten, die ein Angreifer **indirekt steuern** kann, indem er z. B. eine Prompt-Injection auf einer Webseite platziert, die Claude Code anschließend in seine Logs schreibt. Das Audit nimmt deshalb an, dass **jede Zeile der JSONL-Dateien feindlich** ist.

## Was die App **nicht** tut

| Risiko | Status |
|---|---|
| Netzwerkanfragen | Keine. Kein `URLSession`, kein Telemetrie-Endpunkt, kein Update-Check. |
| Codeausführung aus Daten | Keine. Kein `eval`, `Process`, `NSTask`, `system()`, `popen`, `NSAppleScript`-Aufruf mit Daten, kein `WebView`. |
| Markdown-/Linkrendering aus Daten | Keine. Modellnamen (einzige datengetriebene UI-Strings) gehen durch `Text(verbatim:)`. |
| Senden an LLMs | Keine. Es gibt keinen ausgehenden API-Call. Prompt-Injection in den Logs hat keinen Empfänger. |
| Privilegierte Ressourcen | Keine. Keine Entitlements, keine TCC-Anforderungen außer dem regulären Zugriff auf `~/.claude` (User-Heimat). |
| Schreibzugriffe auf User-Daten | Keine. Liest nur. Schreibt ausschließlich in den eigenen In-Memory-Cache. |

## Konkrete Härtungsmaßnahmen

Der Code wurde im Rahmen dieses Reviews um folgende Schutzschichten ergänzt:

### Parser ([Sources/UsageReader.swift](Sources/UsageReader.swift))

- **Symlink-Schutz:** Verzeichnisse und Dateien werden als Symlink gekennzeichnet abgelehnt (`URLResourceKey.isSymbolicLinkKey`).
- **Pfad-Confinement:** Der aufgelöste Pfad jeder besuchten Datei muss mit dem Canonical-Path von `~/.claude/projects` beginnen. Damit kann ein bösartiger Symlink in einem Projektordner nicht auf `/etc/passwd` o. ä. zeigen.
- **Nur reguläre Dateien** (`.isRegularFileKey`) werden geparst — keine Geräte, keine FIFOs.
- **Versteckte Dateien werden übersprungen** (`.skipsHiddenFiles`).
- **Datei-Größenlimit:** 200 MiB. Größere Files werden ignoriert (DoS-Schutz für Memory).
- **Zeilen-Limit:** max. 200.000 Zeilen pro Datei, max. 4 MiB pro Zeile.
- **Identifier-Sanitisierung:** `model`, `message.id`, `requestId`, `sessionId` werden auf einen strikten Allow-List-Zeichensatz (`[A-Za-z0-9-_.:/]`) reduziert und längenbegrenzt. Das neutralisiert Newlines, RTL-Override-Zeichen, ANSI-Escapes und sonstige Display-Tricks, falls die Werte später irgendwo geloggt oder angezeigt werden.
- **Token-Sanitisierung:** Negative Werte → 0; Werte über 1 Mrd. → 0; nicht-finite Doubles → 0. Verhindert Aggregations-Overflows und absurde UI-Anzeigen.
- **Timestamp-Validation:** Werte außerhalb von ±5 Jahren um die aktuelle Zeit werden verworfen, damit ein manipulierter Eintrag nicht künftige oder uralte Buckets vergiftet.
- **Speichersichere I/O:** `Data(contentsOf:options:[.mappedIfSafe])` verwendet Memory-Mapping wenn das Dateisystem es zulässt, sonst regulär.

### UI ([Sources/PopoverView.swift](Sources/PopoverView.swift))

- **`Text(verbatim:)`** für jeden datengetriebenen String. Selbst wenn ein Angreifer es schaffen würde, Sonderzeichen durch die Identifier-Sanitisierung zu schmuggeln, würde SwiftUI sie nicht als `LocalizedStringKey` parsen (also kein Markdown, keine impliziten Links).
- **Keine `Link`/`openURL`-Aufrufe** mit datenabhängigen URLs.
- **`lineLimit(1)`** auf den Modell-Spalten verhindert auch optisch, dass ein langer Wert das Popover sprengt.

### Aggregator

- **Stabile Sortierung** nach Timestamp. Keine `String`-Vergleiche von Zahlen.
- **Dedup** über `message.id` mit reservierter Set-Kapazität (Memory-deterministisch bei normalen Datenmengen).

### Build & Bundle

- **Code-Signing:** ad-hoc (`codesign --sign -`). Damit weiß macOS, dass die ausgeführte Binary nicht nachträglich modifiziert wurde — hat aber keinen Apple-Developer-Trust-Anchor (das wäre nur mit kostenpflichtigem Apple-Developer-Account möglich).
- **Keine Entitlements** angefordert: kein Sandbox-Escape, kein App-Group, kein Hardened-Runtime-Override.
- **`LSUIElement = true`** im Info.plist → kein Dock-Icon, kein App-Switcher-Eintrag, geringere Angriffsfläche.

### Install-Skript ([install.sh](install.sh))

- `set -euo pipefail` aktiviert.
- Alle Pfade hardcodiert, keine User-Eingabe wird in Kommandos eingesetzt.
- `pkill -x ClaudeTokenMonitor` (exakter Name) statt `pkill -f` — kann nicht versehentlich fremde Prozesse mit "ClaudeTokenMonitor" im Argument-String beenden.
- `osascript`-Aufruf für Login-Item enthält ausschließlich konstante Strings, keine Injektion.
- `read -r` für Ja/Nein-Prompt; Eingabe wird nur in einem `case` ausgewertet, niemals an einen Subprozess übergeben.

## Bewusst akzeptierte Restrisiken

| Risiko | Bewertung |
|---|---|
| Ad-hoc-Signatur statt Developer-ID | Ohne kostenpflichtiges Apple-Konto nicht änderbar. macOS warnt einmal beim ersten Start. Das Binary selbst ist signiert, also Integritätsschutz ist gegeben — nur der Trust-Anchor fehlt. |
| App ist nicht App-Sandboxed | App-Sandbox setzt Apple-Developer-ID + entsprechende Entitlements voraus. Da die App selbst nichts privilegiertes tut (keine Schreibvorgänge, kein Netzwerk), ist das vertretbar. |
| Tarif-Tabelle in `Pricing.swift` | Statisch, kann veralten. Keine Sicherheits-, sondern eine Korrektheitsfrage. |
| Memory-Footprint bei extremen Datenmengen | Bei > 200.000 Messages pro Datei wird abgeschnitten; bei sehr vielen JSONL-Dateien wächst das `seenIds`-Set. Bei realistischer Nutzung kein Problem. |

## Ergebnis

Die App führt **keine angreifergesteuerten Daten als Code aus**, **rendert sie nicht als Markdown/Link**, **schickt sie nirgendwohin**, und **operiert ausschließlich im User-Land**.

Da kein LLM nachgelagert mit den geparsten Daten arbeitet und die einzigen UI-Strings (Modellnamen) doppelt gesichert sind (Allow-List-Sanitisierung + `Text(verbatim:)`), gibt es **keinen Prompt-Injection-Vektor**.

Das Risiko-Niveau entspricht einem typischen lokalen Statistik-Tool: vergleichbar mit `tail`, `grep` oder `cat` auf der gleichen Datei.
