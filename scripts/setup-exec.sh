#!/bin/bash

# Compose the ralph-wiggum prompt from the vader plan state file
# Reads .claude/vader/plan.local.md and outputs a single prompt for ralph-wiggum

set -euo pipefail

STATE_FILE=".claude/vader/plan.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: No vader plan found at $STATE_FILE" >&2
  echo "Run /vader first to create a plan." >&2
  exit 1
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
CURRENT_MILESTONE=$(echo "$FRONTMATTER" | grep '^current_milestone:' | sed 's/current_milestone: *//')
TOTAL_MILESTONES=$(echo "$FRONTMATTER" | grep '^total_milestones:' | sed 's/total_milestones: *//')
export MAX_ITERATIONS
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status: *//')

if [[ "$STATUS" == "done" ]]; then
  echo "Error: This plan is already completed." >&2
  exit 1
fi

# Extract plan body (everything after frontmatter)
PLAN_BODY=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

# Update status to executing
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^status: .*/status: executing/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Compose the prompt
cat <<PROMPT
You are executing a vader plan. Work through ALL milestones sequentially.

STATE FILE: .claude/vader/plan.local.md
CURRENT MILESTONE: $CURRENT_MILESTONE (0-indexed, 0 means start from milestone 1)
TOTAL MILESTONES: $TOTAL_MILESTONES

$PLAN_BODY

## Instructions

For EACH milestone (starting from the current one):

1. Read .claude/vader/plan.local.md to check current_milestone
2. Implement the milestone (write code + tests)
3. Run tests to verify the milestone works
4. Use a Task tool (subagent_type=Explore) to review your changes for quality
5. Commit with message: vader: milestone N - [name]
6. Update current_milestone in .claude/vader/plan.local.md (increment by 1)
7. Move to the next milestone

After ALL milestones are complete:
1. Update status to "done" in .claude/vader/plan.local.md
2. Output: <promise>Hurra Vader has Triumphed</promise>

IMPORTANT:
- Do NOT output the promise until ALL milestones are genuinely complete
- If tests fail, fix them before moving on
- Each milestone must be committed separately
- Always verify your work before claiming completion
PROMPT
