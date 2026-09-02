#!/bin/bash

# Vader PreToolUse hook
# status "planned" means the wizard saved a plan and /vader:exec has not run yet.
# Editing in that window is the session skipping the loop to hand-implement, so
# deny it. setup-exec.sh flips the status to "executing", which reopens the gate.

set -euo pipefail

HOOK_INPUT=$(cat)
STATE_FILE="${VADER_STATE_DIR:-.claude/vader}/plan.local.md"

if [[ ! -f "$STATE_FILE" ]] || ! sed -n '2,/^---$/p' "$STATE_FILE" | grep -q '^status: planned$'; then
  exit 0
fi

# Bash is matched too, or a denied Edit just becomes a heredoc. Read-only
# commands pass; redirects to /dev are dropped first so they don't read as writes.
if [[ "$(jq -r '.tool_name // ""' <<<"$HOOK_INPUT" 2>/dev/null)" == "Bash" ]]; then
  CMD=$(jq -r '.tool_input.command // ""' <<<"$HOOK_INPUT" | sed -E 's|[0-9]*>>?[[:space:]]*/dev/[a-z]*||g')
  grep -qE '>|(^|[[:space:]])(sed[[:space:]]+-i|tee|python3?|perl|node|patch)([[:space:]]|$)' <<<"$CMD" || exit 0
fi

# A hook that errors is treated as allow, so the deny path stays dependency-free.
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "A vader plan is saved but execution has not started, so file edits are blocked. Run /vader:exec to start the milestone loop, or /vader:cancel to drop the plan."
  }
}
JSON
