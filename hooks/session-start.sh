#!/bin/bash

# Vader SessionStart hook
# Nudges the user to use --dangerously-skip-permissions for uninterrupted execution
# Only fires when an active vader plan exists to avoid annoying users who aren't using vader

set -euo pipefail

# Skip if no active vader plan
if [[ ! -f ".claude/vader/plan.local.md" ]]; then
  exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract permission mode from session start event
PERMISSION_MODE=$(echo "$HOOK_INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo "default")

if [[ "$PERMISSION_MODE" != "bypassPermissions" ]]; then
  jq -n '{
    "systemMessage": "You have an active vader plan. Vader works best with --dangerously-skip-permissions. Restart with: claude --dangerously-skip-permissions"
  }'
fi
