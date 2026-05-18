#!/usr/bin/env bash
# Build and publish today's Ephemeris issue.
#
# Invoked by launchd (see deploy/name.vadim.ephemeris.plist) at 08:00
# Europe/Zurich every day. Runs Claude Code in headless mode following
# daily-prompt.md. Commits + pushes + posts to Telegram are driven by
# the agent itself (see steps 6 & 7 of daily-prompt.md).

set -euo pipefail

REPO_DIR="/Users/vadim/work/ephemeris"
LOG_DIR="$REPO_DIR/.logs"
DATE_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DATE_LOCAL="$(date +%Y-%m-%d)"
LOG_FILE="$LOG_DIR/$DATE_LOCAL.log"

mkdir -p "$LOG_DIR"

{
  echo "═══════════════════════════════════════════════════════════════"
  echo "Ephemeris daily run · started $DATE_UTC"
  echo "local: $(date) · host: $(hostname) · user: $(whoami)"
  echo "═══════════════════════════════════════════════════════════════"
} >> "$LOG_FILE"

cd "$REPO_DIR"

# Pull latest so we don't fight an out-of-date worktree.
git fetch --quiet origin main
git reset --hard origin/main --quiet
echo "✓ synced to origin/main ($(git rev-parse --short HEAD))" >> "$LOG_FILE"

# Restore .env — it's gitignored, not touched by the reset, but just in case.
if [[ ! -f .env ]]; then
  echo "✗ .env missing — notifier will fail" >> "$LOG_FILE"
fi

# Run the agent. It will fetch sources, render the issue, commit, push, notify.
#   --print            : headless, non-interactive
#   --permission-mode  : auto-approve file/bash ops (cron has no human)
#   --model / --effort : opus + xhigh for best magazine-quality output
PROMPT="$(cat daily-prompt.md)

You are running non-interactively via launchd. Today's date is $DATE_LOCAL (Europe/Zurich). Do the full build now: fetch, select, render, commit, push, notify. Report back in ≤80 words."

/Users/vadim/.local/bin/claude \
  --print \
  --permission-mode bypassPermissions \
  --model opus \
  --effort xhigh \
  --output-format text \
  "$PROMPT" >> "$LOG_FILE" 2>&1

EXIT=$?
echo "═══ finished with exit=$EXIT at $(date -u +%Y-%m-%dT%H:%M:%SZ) ═══" >> "$LOG_FILE"

# Keep last 30 logs.
find "$LOG_DIR" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true

exit "$EXIT"
