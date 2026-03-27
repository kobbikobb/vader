#!/bin/bash

# Compose the ralph-wiggum prompt from the vader plan state file
# Reads .claude/vader/plan.local.md and outputs the prompt to stdout

set -euo pipefail

STATE_FILE=".claude/vader/plan.local.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: No vader plan found at $STATE_FILE" >&2
  echo "Run /vader first to create a plan." >&2
  exit 1
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
export MAX_ITERATIONS
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status: *//')
CREATE_PRS=$(echo "$FRONTMATTER" | grep '^create_prs:' | sed 's/create_prs: *//')
CREATE_PRS="${CREATE_PRS:-false}"

if [[ "$STATUS" == "done" ]]; then
  echo "Error: This plan is already completed." >&2
  exit 1
fi

# Update status to executing
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^status: .*/status: executing/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build branch/PR instructions based on create_prs setting
if [[ "$CREATE_PRS" == "true" ]]; then
  BRANCH_INSTRUCTIONS='## Branch & PR Strategy

For EACH milestone:
- Before starting: `git checkout main && git checkout -b vader/<milestone-slug>`
- After committing: `git push -u origin vader/<milestone-slug>`

After ALL milestones are complete, create a PR for each milestone branch using:
```
gh pr create --head vader/<milestone-slug> --base main --title "<milestone name>" --body "<summary>"
```'
else
  BRANCH_INSTRUCTIONS='## Branch Strategy

All milestones are committed to the current branch sequentially.'
fi

# Output prompt directly to stdout
cat <<PROMPT
You are executing a vader plan. Work through ALL milestones sequentially.

STATE FILE: .claude/vader/plan.local.md

Read the state file above FIRST to get the full plan, milestones, scope, and constraints.
Check the frontmatter for current_milestone and total_milestones.

$BRANCH_INSTRUCTIONS

## Instructions

For EACH milestone (starting from the current one):

1. Read .claude/vader/plan.local.md to check current_milestone
2. Implement the milestone (write code + tests)
3. Run the project's lint, format, and typecheck commands to verify code quality
4. Run tests to verify the milestone works
5. Review your own diff for obvious issues (security, missing edge cases, unused code)
6. Commit with message: vader: milestone N - [name]
7. Update current_milestone in .claude/vader/plan.local.md (increment by 1)
8. Move to the next milestone

After ALL milestones are complete:
1. Update status to "done" in .claude/vader/plan.local.md
2. Output: <promise>Hurra Vader has Triumphed</promise>

IMPORTANT:
- Do NOT output the promise until ALL milestones are genuinely complete
- If tests or lint fail, fix them before moving on
- Each milestone must be committed separately
- Always verify your work before claiming completion
PROMPT
