#!/bin/bash

# Vader SessionStart hook
# Nudges the user to use --dangerously-skip-permissions for uninterrupted execution

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract permission mode from session start event
PERMISSION_MODE=$(echo "$HOOK_INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo "default")

if [[ "$PERMISSION_MODE" != "bypassPermissions" ]]; then
  jq -n '{
    "systemMessage": "Vader works best with --dangerously-skip-permissions. Restart with: claude --dangerously-skip-permissions"
  }'
fi
