#!/bin/bash

# Compose the thin-router execution prompt from the vader plan state file
# Reads .claude/vader/plan.local.md and outputs the prompt to stdout
#
# The prompt is a THIN ROUTER: the supervisor holds only the current milestone
# index and latest verdict. All heavy content (personas, milestone scope, diffs,
# test output, full reports) stays out of the supervisor context:
#   - personas are referenced by path, read inside each subagent
#   - Executor/Verifier write full reports to files; subagents return ONE verdict line
#   - durable memory lives in the state file + reports/, resumable after /clear

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${VADER_STATE_DIR:-.claude/vader}"
STATE_FILE="$STATE_DIR/plan.local.md"
REPORTS_DIR="$STATE_DIR/reports"
INVARIANTS_FILE="$REPORTS_DIR/invariants.md"
EXECUTOR_PERSONA="$PLUGIN_ROOT/agents/executor.md"
VERIFIER_PERSONA="$PLUGIN_ROOT/agents/verifier.md"

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
STATE_REPORTS_DIR=$(echo "$FRONTMATTER" | grep '^reports_dir:' | sed 's/reports_dir: *//' || true)
REPORTS_DIR="${STATE_REPORTS_DIR:-$REPORTS_DIR}"
INVARIANTS_FILE="${REPORTS_DIR}/invariants.md"
CHECKPOINT=$(echo "$FRONTMATTER" | grep '^checkpoint:' | sed 's/checkpoint: *//' || true)
CHECKPOINT="${CHECKPOINT:-idle}"
CURRENT_MILESTONE=$(echo "$FRONTMATTER" | grep '^current_milestone:' | sed 's/current_milestone: *//')
TOTAL_MILESTONES=$(echo "$FRONTMATTER" | grep '^total_milestones:' | sed 's/total_milestones: *//')

if [[ "$STATUS" == "done" ]]; then
  echo "Error: This plan is already completed." >&2
  exit 1
fi

# Atomic frontmatter key update: scope sed to frontmatter block only, then mv.
update_state_key() {
  local key="$1" value="$2"
  local tmp
  tmp="${STATE_FILE}.tmp.$$"
  sed "/^---$/,/^---$/{ /^---$/!s/^${key}: .*/${key}: ${value}/; }" "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

# Update status to executing
update_state_key "status" "executing"

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

Before starting the first milestone, create a working branch to avoid committing
directly to the checked-out branch:

```
WORK_BRANCH="vader/$(date +%s)"
git checkout -b "$WORK_BRANCH"
```

All milestones are committed to this branch sequentially. The branch name is
recorded in the executor report for later reference.'
fi

# Output prompt directly to stdout
cat <<PROMPT
You are executing a vader plan as a THIN ROUTER. You do not hold milestone context
in your own context — every milestone runs in a fresh subagent, and all durable memory
lives on disk. You only read tiny verdicts and the current milestone index.

STATE FILE: $STATE_FILE
REPORTS DIR: $REPORTS_DIR
INVARIANTS FILE: $INVARIANTS_FILE
CURRENT MILESTONE: $CURRENT_MILESTONE of $TOTAL_MILESTONES
CHECKPOINT: $CHECKPOINT

## Context discipline (non-negotiable)

- NEVER inline the plan body, milestone scope, personas, diffs, or test output into your
  own reasoning. Subagents read these from disk themselves.
- To learn the current milestone, read ONLY the \`## Milestone N\` section of the state
  file (grep the section header, then read just that range). Do not hold all milestones
  in context at once.
- Executor and Verifier personas are files, not text you carry:
  - Executor persona: $EXECUTOR_PERSONA
  - Verifier persona: $VERIFIER_PERSONA
  When spawning an agent, tell it to Read its persona file first. The persona text never
  enters your own context.
- Each subagent returns ONLY a verdict (one word + one-line summary). Full reports go to:
  - $REPORTS_DIR/milestone-N-executor.md
  - $REPORTS_DIR/milestone-N-verifier.md

## Crash checkpointing

The state file tracks a \`checkpoint\` field that records where you are within the
current milestone's lifecycle. If execution is interrupted (crash, /clear, context
compaction), resume by reading the checkpoint and skipping completed steps.

Checkpoint values and what they mean:
- \`idle\` — no work started on the current milestone. Start from step 1.
- \`executor_done\` — Executor returned \`done\` but Verifier has not run.
  Skip to step 4 (spawn Verifier).
- \`verifier_approved\` — Verifier returned \`approve\` but commit not yet made.
  Skip to step 6 (commit).

After each transition, update the checkpoint via atomic tempfile+mv:
\`\`\`
sed "/^---$/,/^---$/{ /^---$/!s/^checkpoint: .*/checkpoint: <new-value>/; }" "$STATE_FILE" > "$STATE_FILE.tmp.$$"
mv "$STATE_FILE.tmp.$$" "$STATE_FILE"
\`\`\`

After a milestone is committed and current_milestone incremented, reset checkpoint
to \`idle\` for the next milestone.

$BRANCH_INSTRUCTIONS

## Plan overrides (supersede persona defaults)

The plan's constraints may require actions the executor persona discourages as general
rules (e.g. modifying generated files, touching files outside the milestone scope).
When the plan mandates something the persona forbids, the plan wins.

Include these overrides when spawning each Executor:
- Read the \`## Constraints\` section of the plan file.
- If constraints mandate regenerating files, modifying generated output, or touching
  files beyond the milestone scope, pass that as an explicit override to the Executor:
  "The plan constraints require [X]. This overrides the persona rule against [Y]."
- The Executor must follow the override for this milestone only; persona defaults
  apply everywhere else.

## Concurrency control

When an Executor fans out to sub-subagents (clusters, bulk conversions, parallel tasks):
- Run cluster subagents **sequentially**, not in parallel. Each cluster writes to
  shared files (generated tables, policies, registries). Parallel writes race.
- If the work is truly independent (different files, no shared output), parallel is
  fine — but default to sequential unless you can prove independence.
- The Executor persona instructs subagents to commit incrementally. Respect this:
  do not batch all cluster work before any commit.

## Per-milestone procedure

For each milestone from \`current_milestone\` (1-based) up to \`total_milestones\`:

1. Derive N and its name from the state file frontmatter + the \`## Milestone N\` header.
   Check the checkpoint. If \`idle\`, start from step 1. If \`executor_done\`, skip
   to step 4. If \`verifier_approved\`, skip to step 6.
2. Read project tooling (test/lint/typecheck) — see Hard Rules below. Pass these to the
   subagents; do not run the suite yourself.
3. Spawn a fresh **Executor** Agent:
   - Tell it to Read $EXECUTOR_PERSONA (its role) then the \`## Milestone N\` section.
   - Pass the plan constraints as overrides (see Plan overrides section above).
   - Instruct it to implement the milestone, write tests for each scenario, run quality
     gates, and WRITE its full report to $REPORTS_DIR/milestone-N-executor.md.
   - Instruct it to respond with ONLY: \`done\` or \`needs-fix\` plus one line.
   - On success: update checkpoint to \`executor_done\`.
4. Spawn a fresh **Verifier** Agent:
   - Tell it to Read $VERIFIER_PERSONA, the milestone section, and
     $REPORTS_DIR/milestone-N-executor.md.
   - Pass \`is_final: false\` for every milestone, including the last one —
     Final Integration is the only \`is_final: true\` pass.
   - Instruct it to validate each scenario by evidence, WRITE its report to
     $REPORTS_DIR/milestone-N-verifier.md, and APPEND a known-good invariant entry to
     $INVARIANTS_FILE.
   - Instruct it to respond with ONLY: \`approve\` or \`needs-fix\` plus one line.
   - On approve: update checkpoint to \`verifier_approved\`.
5. Fix loop: if Verifier returns \`needs-fix\`, spawn a fresh Executor with the issues,
   then a fresh Verifier. Maximum 3 Executor-Verifier cycles per milestone. If issues
   persist after 3 cycles, stop and report.
6. Commit: \`vader: milestone N - [name]\`. If create_prs is enabled, push and create a PR.
7. Persist structural anchor: append a short \`## Branch/PR\` block to
   $REPORTS_DIR/milestone-N-executor.md recording the branch name and PR URL/number, so
   later milestones and Final Integration can anchor on them from disk. Then update
   \`current_milestone\` in $STATE_FILE (increment by 1) and reset \`checkpoint\` to
   \`idle\` via a tempfile+mv atomic write; never edit in place.

## Inter-milestone verification gate

Before advancing to the next milestone, run this 10-second check. It catches ghost
subagent reports (a subagent that claimed success but made no real change):

1. If create_prs: \`git branch --list vader/<slug>\` — branch exists
2. If create_prs: \`gh pr view <head>\` — PR exists (skip if no PR was created)
3. \`git status --short\` + \`git log -1 --oneline\` — a milestone commit was made
   (or, if create_prs: \`git diff main..<branch> --stat\` — non-empty changes)

If ANY check fails, re-verify instead of trusting the report: read the Executor report
and the diff. If three separate milestones fail this gate, ABORT execution (do not
retry) and report. This gate is for supervision integrity, not implementation — do not
spend retry cycles here.

## Final Integration pass (after the LAST user milestone)

Run once in a FRESH Verifier, not from accumulated context:

1. Run the project's full test suite, full typecheck, and any sanity scripts.
2. Spawn one final Verifier with \`is_final: true\` over the whole branch:
   - Tell it to read $VERIFIER_PERSONA, ${INVARIANTS_FILE}, and every
     \`$REPORTS_DIR/milestone-*-verifier.md\` as its cross-milestone oracle.
   - Also tell it to grep for any old pattern whose absence was recorded in the
     invariants file — those must still return zero.
3. If Final Integration fails, treat it as needs-fix on the LAST milestone and loop
   (still subject to the 3-cycle cap).
4. Only after Final Integration approves: update status to "done" via atomic write.
5. Output: <promise>Hurra Vader has Triumphed</promise>

## Hard Rules

- Do NOT output the promise until ALL milestones AND the Final Integration pass are
  genuinely complete.
- Do NOT commit if lint, typecheck, or tests fail — fix first.
- Do NOT skip quality gates — they catch real CI failures.
- Each milestone must be committed separately.
- Always verify work through the Verifier agent before committing.
- Always route subagent reports to files; never let full reports or diffs accumulate in
  your own context.
- If the Verifier keeps rejecting after 3 cycles, stop execution and report.
- Recover project tooling from the repo CLAUDE.md or manifest (package.json / Makefile /
  pyproject.toml) and pass exact commands to subagents — do not guess.
- Update the checkpoint after every state transition. A crash without a checkpoint
  means the next resume cannot skip completed work.
PROMPT
