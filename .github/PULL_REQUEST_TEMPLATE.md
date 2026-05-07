## What does this PR do?
<!-- One paragraph. What changed and why. -->

## How was it tested?
- [ ] `./build.sh` succeeds
- [ ] App launches without errors in `log show --predicate 'process == "ClaudeTokenMonitor"'`
- [ ] Token numbers in the popover match `ccusage` output
- [ ] Desktop widget renders correctly in all three sizes

## Checklist
- [ ] No new network requests
- [ ] No new external code execution from JSONL data
- [ ] If touching the parser, hardening invariants in `SECURITY.md` still hold
- [ ] CHANGELOG.md updated under `[Unreleased]`
