#!/bin/bash

# Check if Claude Code is running with bypass permissions mode
# Used by /vader:exec to warn if permissions will block the loop

set -euo pipefail

# Read session info from stdin if available, otherwise check environment
# The permission mode can be detected by checking if --dangerously-skip-permissions was used
# We check by looking at the Claude Code process args or environment

# Simple heuristic: check if we can detect the permission mode
# In practice, the skill reads this output and acts on it
if [[ "${CLAUDE_PERMISSION_MODE:-}" == "bypassPermissions" ]]; then
  echo "bypassPermissions"
else
  # Try to detect from process - fallback to default
  if pgrep -f 'claude.*--dangerously-skip-permissions' >/dev/null 2>&1; then
    echo "bypassPermissions"
  else
    echo "default"
  fi
fi
