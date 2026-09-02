#!/bin/bash

# Vader PreToolUse hook
# status "planned" means the wizard saved a plan and /vader:exec has not run yet.
# Editing in that window is the session skipping the loop to hand-implement, so
# deny it. setup-exec.sh flips the status to "executing", which reopens the gate.

set -euo pipefail

HOOK_INPUT=$(cat)
STATE_FILE="${VADER_STATE_DIR:-.claude/vader}/plan.local.md"

if [[ ! -f "$STATE_FILE" ]] || ! sed -n '2,/^---$/p' "$STATE_FILE" | grep -qE '^status: planned[[:space:]]*$'; then
  exit 0
fi

TOOL=$(jq -r '.tool_name // ""' <<<"$HOOK_INPUT" 2>/dev/null || echo "")
CMD=$(jq -r '.tool_input.command // ""' <<<"$HOOK_INPUT" 2>/dev/null || echo "")

case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  # Guessing which commands write leaks both ways, so only vader's own commands pass.
  Bash)
    if grep -qE 'CLAUDE_PLUGIN_ROOT|plan\.local\.md' <<<"$CMD"; then
      exit 0
    fi
    ;;
  # An unreadable payload allows, or a broken jq locks the session out of /vader:cancel.
  *) exit 0 ;;
esac

# A hook that errors is treated as allow, so the deny path stays dependency-free.
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "A vader plan is saved but execution has not started, so edits are blocked. Run /vader:exec to start the milestone loop, or /vader:cancel to drop the plan."
  }
}
JSON
