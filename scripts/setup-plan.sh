#!/bin/bash

# Write the vader plan state file from wizard output
# Usage: setup-plan.sh <title> <scope> <constraints> <success_criteria> <milestones_json> <max_iterations>

set -euo pipefail

TITLE="${1:?Error: title is required}"
SCOPE="${2:?Error: scope is required}"
CONSTRAINTS="${3:?Error: constraints are required}"
SUCCESS_CRITERIA="${4:?Error: success criteria are required}"
MILESTONES_JSON="${5:?Error: milestones JSON is required}"
MAX_ITERATIONS="${6:-15}"
CREATE_PRS="${7:-true}"

# Validate max_iterations is a number
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Error: max_iterations must be a positive integer, got: $MAX_ITERATIONS" >&2
  exit 1
fi

# Validate milestones JSON
if ! echo "$MILESTONES_JSON" | jq empty 2>/dev/null; then
  echo "Error: milestones must be valid JSON" >&2
  exit 1
fi

TOTAL_MILESTONES=$(echo "$MILESTONES_JSON" | jq 'length')

if [[ "$TOTAL_MILESTONES" -lt 1 ]]; then
  echo "Error: at least one milestone is required" >&2
  exit 1
fi

# Generate session ID
SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)

# Create state directory
mkdir -p .claude/vader

# Write state file
STATE_FILE=".claude/vader/plan.local.md"

cat > "$STATE_FILE" <<FRONTMATTER
---
session_id: "$SESSION_ID"
status: planned
current_milestone: 0
total_milestones: $TOTAL_MILESTONES
max_iterations: $MAX_ITERATIONS
create_prs: $CREATE_PRS
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---
FRONTMATTER

{
  echo "# Plan: $TITLE"
  echo ""
  echo "## Scope"
  echo "$SCOPE"
  echo ""
  echo "## Constraints"
  echo "$CONSTRAINTS"
  echo ""
  echo "## Success Criteria"
  echo "$SUCCESS_CRITERIA"
  echo ""

  # Write milestones from JSON
  for i in $(seq 0 $((TOTAL_MILESTONES - 1))); do
    MILESTONE=$(echo "$MILESTONES_JSON" | jq -r ".[$i]")
    NAME=$(echo "$MILESTONE" | jq -r '.name')
    M_SCOPE=$(echo "$MILESTONE" | jq -r '.scope // empty')
    FILES=$(echo "$MILESTONE" | jq -r '.files[]? // empty')
    CRITERIA=$(echo "$MILESTONE" | jq -r '.success_criteria[]? // empty')

    echo "## Milestone $((i + 1)): $NAME"
    if [[ -n "$M_SCOPE" ]]; then
      echo "$M_SCOPE"
    fi
    echo ""
    echo "### Files"
    if [[ -n "$FILES" ]]; then
      echo "$MILESTONE" | jq -r '.files[] | "- \(.)"'
    else
      echo "- (to be determined)"
    fi
    echo ""
    echo "### Success Criteria"
    if [[ -n "$CRITERIA" ]]; then
      echo "$MILESTONE" | jq -r '.success_criteria[] | "- \(.)"'
    else
      echo "- (to be determined)"
    fi
    echo ""
  done
} >> "$STATE_FILE"

echo "Plan saved to $STATE_FILE"
echo "Total milestones: $TOTAL_MILESTONES"
echo "Max iterations: $MAX_ITERATIONS"
echo "Run /clear -> followed by /vader:exec to start execution."
