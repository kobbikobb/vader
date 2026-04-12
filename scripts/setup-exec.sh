#!/bin/bash

# Compose the ralph-wiggum prompt from the vader plan state file
# Reads .claude/vader/plan.local.md and outputs the prompt to stdout
# Inlines executor and verifier agent personas into the prompt

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
CREATE_PRS=$(echo "$FRONTMATTER" | grep '^create_prs:' | sed 's/create_prs: *//' || true)
CREATE_PRS="${CREATE_PRS:-true}"

if [[ "$STATUS" == "done" ]]; then
  echo "Error: This plan is already completed." >&2
  exit 1
fi

# Read agent personas
EXECUTOR_PERSONA=""
VERIFIER_PERSONA=""
if [[ -f "$PLUGIN_ROOT/agents/executor.md" ]]; then
  EXECUTOR_PERSONA=$(cat "$PLUGIN_ROOT/agents/executor.md")
fi
if [[ -f "$PLUGIN_ROOT/agents/verifier.md" ]]; then
  VERIFIER_PERSONA=$(cat "$PLUGIN_ROOT/agents/verifier.md")
fi

# Update status to executing
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^status: .*/status: executing/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Build branch/PR instructions based on create_prs setting
if [[ "$CREATE_PRS" == "true" ]]; then
  BRANCH_INSTRUCTIONS='## Branch & PR Strategy

For EACH milestone:
- Before starting: `git checkout main && git pull && git checkout -b vader/<milestone-slug>`
- After committing: push and create a PR immediately:
  ```
  git push -u origin vader/<milestone-slug>
  gh pr create --head vader/<milestone-slug> --base main --title "<milestone name>" --body "<summary>"
  ```
- Then switch back to main before starting the next milestone'
else
  BRANCH_INSTRUCTIONS='## Branch Strategy

All milestones are committed to the current branch sequentially.'
fi

# Output prompt directly to stdout
cat <<PROMPT
You are executing a vader plan. Work through ALL milestones sequentially using specialized agents.

STATE FILE: .claude/vader/plan.local.md

Read the state file above FIRST to get the full plan, milestones, scope, and constraints.
Check the frontmatter for current_milestone and total_milestones.

$BRANCH_INSTRUCTIONS

## Agent Personas

Use the following personas when spawning agents via the Agent tool.

### Executor

${EXECUTOR_PERSONA}

### Verifier

${VERIFIER_PERSONA}

## Instructions

For EACH milestone (starting from the current one):

1. Read .claude/vader/plan.local.md to check current_milestone
2. Spawn an **Executor** agent using the Agent tool:
   - Include the Executor persona above in the agent prompt
   - Include the milestone scope, files, and success criteria from the plan
   - The Executor implements the milestone, writes tests, and runs quality gates (lint, typecheck, tests)
3. After the Executor completes, spawn a **Verifier** agent using the Agent tool:
   - Include the Verifier persona above in the agent prompt
   - Include the milestone success criteria and a summary of what was implemented
   - The Verifier validates the work and reports approve or needs-fix
4. If the Verifier reports needs-fix, spawn a new Executor agent with the issues to fix
   - Maximum 3 Executor-Verifier cycles per milestone
   - If issues persist after 3 cycles, stop and report the problem
5. Commit with message: vader: milestone N - [name]
6. If create_prs is enabled: push the branch and create a PR (see Branch & PR Strategy above)
7. Update current_milestone in .claude/vader/plan.local.md (increment by 1)
8. Switch back to main before starting the next milestone

After ALL milestones are complete:
1. Update status to "done" in .claude/vader/plan.local.md
2. Output: <promise>Hurra Vader has Triumphed</promise>

## Hard Rules
- Do NOT output the promise until ALL milestones are genuinely complete
- Do NOT commit if lint, typecheck, or tests fail — fix first
- Do NOT skip quality gates — they catch real CI failures
- Each milestone must be committed separately
- Always verify work through the Verifier agent before committing
- If the Verifier keeps rejecting after 3 cycles, stop execution and report
PROMPT
