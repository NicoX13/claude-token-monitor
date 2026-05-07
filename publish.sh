#!/usr/bin/env bash
# One-shot helper to publish this repo to GitHub.
#
# Prerequisites:
#   1. gh is installed   (brew install gh — already done)
#   2. You ran           gh auth login --web      (one-time, opens browser)
#
# What it does:
#   - Verifies you're authenticated.
#   - Creates a public repo at github.com/<your-username>/claude-token-monitor
#     if it doesn't exist yet.
#   - Pushes main + tags.
#   - Tags v1.0.0 if not already tagged → triggers the Release workflow.
#   - Prints the repo URL when done.
set -euo pipefail

cd "$(dirname "$0")"

REPO_NAME="claude-token-monitor"
DESCRIPTION="Native macOS app that surfaces your Claude Code token usage — menu bar item, detail popover, and a desktop widget. No Xcode, no network, hardened parser."
HOMEPAGE=""
TAG="v1.0.0"

# ----------------------------------------------------------------------- auth
if ! gh auth status >/dev/null 2>&1; then
    echo "==> gh is not authenticated. Run this once and come back:"
    echo
    echo "      gh auth login --web"
    echo
    echo "    Then re-run ./publish.sh"
    exit 1
fi

USER=$(gh api user --jq .login)
echo "==> Authenticated as: ${USER}"

# ------------------------------------------------------------------- create
if gh repo view "${USER}/${REPO_NAME}" >/dev/null 2>&1; then
    echo "==> Repo ${USER}/${REPO_NAME} already exists — re-using it"
else
    echo "==> Creating public repo ${USER}/${REPO_NAME}"
    gh repo create "${REPO_NAME}" \
        --public \
        --description "${DESCRIPTION}" \
        --source=. \
        --remote=origin \
        --push=false
fi

# ------------------------------------------------------------------- remote
if git remote get-url origin >/dev/null 2>&1; then
    echo "==> Origin already configured: $(git remote get-url origin)"
else
    git remote add origin "https://github.com/${USER}/${REPO_NAME}.git"
fi

# --------------------------------------------------------------------- push
echo "==> Pushing main"
git push -u origin main

# ----------------------------------------------------------------------- tag
if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo "==> Tag ${TAG} already exists — skipping"
else
    echo "==> Tagging ${TAG}"
    git tag -a "${TAG}" -m "Initial release"
    git push origin "${TAG}"
fi

# ---------------------------------------------------------------- topics + about
echo "==> Setting topics"
gh repo edit --add-topic macos --add-topic swift --add-topic widget \
              --add-topic menu-bar-app --add-topic claude --add-topic anthropic \
              --add-topic token-usage --add-topic claude-code \
              --add-topic swiftui --add-topic appkit \
              --add-topic widgetkit \
   2>/dev/null || true

echo
echo "==> Done."
echo "    https://github.com/${USER}/${REPO_NAME}"
echo "    https://github.com/${USER}/${REPO_NAME}/actions"
echo "    https://github.com/${USER}/${REPO_NAME}/releases"
