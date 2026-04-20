#!/bin/bash

# Vader SessionStart hook
# Always prints the plugin version. When an active vader plan exists and the
# session is not running with --dangerously-skip-permissions, it also nudges
# the user to restart in bypass-permissions mode.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
PLUGIN_JSON=""
if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]]; then
  PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
elif [[ -f "$(dirname "$0")/../.claude-plugin/plugin.json" ]]; then
  PLUGIN_JSON="$(dirname "$0")/../.claude-plugin/plugin.json"
fi

VERSION="unknown"
if [[ -n "$PLUGIN_JSON" ]]; then
  VERSION=$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null || echo unknown)
fi

HOOK_INPUT=$(cat)
PERMISSION_MODE=$(echo "$HOOK_INPUT" | jq -r '.permission_mode // "default"' 2>/dev/null || echo "default")

MESSAGE="Vader v${VERSION}"

if [[ -f ".claude/vader/plan.local.md" && "$PERMISSION_MODE" != "bypassPermissions" ]]; then
  MESSAGE+=" — active plan detected. Vader works best with --dangerously-skip-permissions. Restart with: claude --dangerously-skip-permissions"
fi

jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
