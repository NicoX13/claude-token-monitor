# Contributing

Thanks for taking an interest! This project is small on purpose — but contributions are welcome.

## Build prerequisites

- macOS 13 or newer
- **Command Line Tools** for Xcode (no full Xcode required for the host app):
  ```
  xcode-select --install
  ```

## Build & run

```bash
git clone https://github.com/NicoX13/claude-token-monitor.git
cd claude-token-monitor
./build.sh
open ".build/Claude Token Monitor.app"
```

## Run the parser as a CLI selftest

The JSONL parser is plain Foundation — you can compile it standalone to debug
aggregation:

```bash
mkdir -p /tmp/ctm-cli
cp Sources/Models.swift Sources/Pricing.swift Sources/UsageReader.swift /tmp/ctm-cli/
cat > /tmp/ctm-cli/main.swift <<'EOF'
import Foundation
let r = UsageReader().generateReport()
print("entries=\(r.totalEntries) tokens=\(r.allTime.totalTokens) cost=$\(String(format: "%.2f", r.allTime.cost))")
EOF
swiftc -O -framework Foundation /tmp/ctm-cli/*.swift -o /tmp/ctm-cli/cli
/tmp/ctm-cli/cli
```

## Code style

- 4-space indentation, no tabs.
- Keep comments minimal — explain WHY, not WHAT.
- New attacker-controlled string in the UI? Run it through `sanitiseIdentifier(...)`
  *and* render it via `Text(verbatim:)`. Never `Text(myDataString)` without thinking.
- New token field from JSONL? Sanitise via `sanitiseTokenCount(...)`.

## Areas where help is wanted

- **WidgetKit extension under a real Apple Developer ID.** The code in
  `Sources/Widget/` is complete; it just needs a signed parent app to be
  loaded by `chronod`. If you have a Developer ID and want to ship a notarised
  release, please open an issue first so we can coordinate signing.
- **Updated pricing tables** when Anthropic changes API rates.
- **Localisations** beyond German.
- **Apple Watch complication** powered by the same data.

## Security

If you find a security issue, please **don't** open a public issue. Use
[GitHub Security Advisories](https://github.com/NicoX13/claude-token-monitor/security/advisories/new)
instead.

The project's threat model and hardening invariants are documented in
[SECURITY.md](SECURITY.md). New parser code must preserve those invariants.

## Releasing

1. Update `CHANGELOG.md` — move `[Unreleased]` items under a new version heading.
2. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
3. `git commit -am "release: vX.Y.Z" && git tag vX.Y.Z`
4. `git push && git push --tags`
5. The release workflow (`.github/workflows/build.yml`) will build, package,
   and attach the zipped `.app` to the GitHub release automatically.
