#!/bin/bash

# Vader PreToolUse hook
# status "planned" means the wizard saved a plan and /vader:exec has not run yet.
# Editing in that window is the session skipping the loop to hand-implement, so
# deny it. setup-exec.sh flips the status to "executing", which reopens the gate.

set -euo pipefail

HOOK_INPUT=$(cat)
STATE_FILE="${VADER_STATE_DIR:-.claude/vader}/plan.local.md"
# shellcheck disable=SC2016  # both are literal command text, never expanded here
CANCEL_CMD='rm -f "${VADER_STATE_DIR:-.claude/vader}/plan.local.md"'
VADER_SCRIPT='^"\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-z-]+\.sh"'

# A CRLF plan file never closes the frontmatter range, so strip \r before parsing.
if [[ ! -f "$STATE_FILE" ]] || ! tr -d '\r' < "$STATE_FILE" | sed -n '2,/^---$/p' | grep -qE '^status: planned[[:space:]]*$'; then
  exit 0
fi

TOOL=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
CMD=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  # Guessing which commands write leaks both ways, so only vader's own pass, and
  # only as the whole command: matching the name anywhere lets "cp plan.local.md
  # src/app.ts" and a second line after the invocation walk through.
  Bash)
    if [[ "$CMD" == "$CANCEL_CMD" ]]; then
      exit 0
    elif [[ "$CMD" =~ $VADER_SCRIPT ]]; then
      # Quoted plan prose carries ";" and "&" all the time, so chaining is only
      # looked for outside the arguments.
      BARE=$(echo "${CMD#*.sh\"}" | sed "s/\"[^\"]*\"//g; s/'[^']*'//g")
      if [[ "$CMD" != *$'\n'* ]] && ! echo "$BARE" | grep -qE '[;&|<>`]|\$\('; then
        exit 0
      fi
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
    "permissionDecisionReason": "A vader plan is saved but execution has not started, so edits and shell commands other than vader's own are blocked. Run /vader:exec to start the milestone loop, or /vader:cancel to drop the plan."
  }
}
JSON
