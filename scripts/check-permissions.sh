#!/bin/bash

# Check if Claude Code is running with bypass permissions mode
# Used by /vader:exec to warn if permissions will block the loop
#
# Detection is best-effort. The session-start hook is more reliable
# since it receives permission_mode in the hook input JSON.

set -euo pipefail

# Check environment variable (set by some Claude Code versions)
if [[ "${CLAUDE_PERMISSION_MODE:-}" == "bypassPermissions" ]]; then
  echo "bypassPermissions"
  exit 0
fi

# Fallback: assume default (the session-start hook will catch it more reliably)
echo "default"
