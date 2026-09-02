#!/bin/bash

# Vader PreToolUse hook
# status "planned" means the wizard saved a plan and /vader:exec has not run yet.
# Editing in that window is the session skipping the loop to hand-implement, so
# deny it. setup-exec.sh flips the status to "executing", which reopens the gate.

set -euo pipefail

cat > /dev/null

STATE_FILE="${VADER_STATE_DIR:-.claude/vader}/plan.local.md"

if [[ ! -f "$STATE_FILE" ]] || ! grep -q '^status: planned$' "$STATE_FILE"; then
  exit 0
fi

REASON="A vader plan is saved but execution has not started, so file edits are blocked. Run /vader:exec to start the milestone loop, or /vader:cancel to drop the plan."

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
