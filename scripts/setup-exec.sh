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
CREATE_PRS="${CREATE_PRS:-true}"

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
You are executing a vader plan. Work through ALL milestones sequentially.

STATE FILE: .claude/vader/plan.local.md

Read the state file above FIRST to get the full plan, milestones, scope, and constraints.
Check the frontmatter for current_milestone and total_milestones.

$BRANCH_INSTRUCTIONS

## Instructions

For EACH milestone (starting from the current one):

### 1. Plan
- Read .claude/vader/plan.local.md to check current_milestone

### 2. Implement
- Write code + tests for the milestone
- Every new public function/method MUST have a corresponding test
- Search for all callers, variants, and related code paths of anything you change (e.g. legacy versions, feature-flagged variants, shared interfaces) and update them too

### 3. Quality Gates (MUST ALL PASS before committing)

Run these in order. If any fail, fix and re-run. Do NOT skip or commit with failures.

a) **Lint & Format**: Run the project's lint and format commands (e.g. eslint, flake8, black, csharpier, etc.). Detect them from package.json scripts, Makefile targets, or CI config.

b) **Typecheck**: Run the project's type checker if applicable (e.g. tsc --noEmit, mypy, dotnet build).

c) **Codegen**: If you changed proto files, schema files, or any generated code, run the codegen/build step (e.g. protoc, make build-java-migrations, graphql-codegen). Check CI config for codegen verification steps.

d) **Tests**: Run unit tests for the files you changed. Verify exit code is 0. If integration tests exist and are runnable locally, run those too.

e) **Test coverage check**: Verify that every new public function/method you added has at least one test. If not, write the missing tests now.

### 4. Self-Review

Before committing, review your own diff and check:
- Does this change make any existing feature redundant or duplicate? If so, reconcile (remove the duplicate or differentiate the behavior).
- Are there stale closures in React hooks? (useCallback/useMemo with missing deps closing over mutable state)
- Does any changed SQL use the right operator for the data type? (e.g. ->> for JSON objects vs arrays)
- Are all error paths handled? Any new exceptions that callers don't expect?
- Did you update ALL variants of the code you changed? (legacy versions, feature-flagged paths)

### 5. Commit & Ship
- Commit with message: vader: milestone N - [name]
- If create_prs is enabled: push the branch and create a PR (see Branch & PR Strategy above)
- Update current_milestone in .claude/vader/plan.local.md (increment by 1)
- Switch back to main before starting the next milestone

After ALL milestones are complete:
1. Update status to "done" in .claude/vader/plan.local.md
2. Output: <promise>Hurra Vader has Triumphed</promise>

## Hard Rules
- Do NOT output the promise until ALL milestones are genuinely complete
- Do NOT commit if lint, typecheck, or tests fail — fix first
- Do NOT skip quality gates — they catch real CI failures
- Each milestone must be committed separately
- Always verify your work before claiming completion
PROMPT
