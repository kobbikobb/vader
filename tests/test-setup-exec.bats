#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/setup-exec.sh"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

create_plan_file() {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "test-123"
status: planned
current_milestone: 1
checkpoint: idle
total_milestones: 2
max_iterations: 15
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Test Project

## Scope
Build a test thing

## Constraints
- Use Bash

## Success Criteria
- All tests pass

## Milestone 1: Setup
Initial project setup

### Files
- src/index.sh (add)

### Success Criteria
- Project runs

## Milestone 2: Feature
Add the feature

### Files
- src/feature.sh (add)

### Success Criteria
- Feature works
EOF
}

@test "should fail when no plan file exists" {
  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"No vader plan found"* ]]
}

@test "should output prompt to stdout referencing state file instead of inlining plan" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"executing a vader plan"* ]]
  [[ "$output" == *"STATE FILE"* ]]
  [[ "$output" == *"current_milestone"* ]]
  # Plan body should NOT be inlined in the prompt
  [[ "$output" != *"Milestone 1: Setup"* ]]
  [[ "$output" != *"Milestone 2: Feature"* ]]
}

@test "should update status to executing" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  grep -q "status: executing" .claude/vader/plan.local.md
}

@test "should fail when plan status is done" {
  create_plan_file
  sed 's/status: planned/status: done/' .claude/vader/plan.local.md > .claude/vader/plan.local.md.tmp
  mv .claude/vader/plan.local.md.tmp .claude/vader/plan.local.md

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"already completed"* ]]
}

@test "should include completion promise instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Hurra Vader has Triumphed"* ]]
}

@test "should include milestone workflow instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"commit"* ]]
  [[ "$output" == *"current_milestone"* ]]
}

@test "should include executor persona path reference, not inline persona" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Executor"* ]]
  # Persona is referenced by path so the supervisor never carries the body
  [[ "$output" == *"agents/executor.md"* ]]
  [[ "$output" != *"Implement a single milestone"* ]]
}

@test "should include verifier persona path reference, not inline persona" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Verifier"* ]]
  [[ "$output" == *"agents/verifier.md"* ]]
  [[ "$output" != *"Validate that a milestone achieved its goal"* ]]
}

@test "should include max retry instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Maximum 3"* ]]
}

@test "should route subagent reports to the reports dir, verdict-only return" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"reports/milestone-N-executor.md"* ]]
  [[ "$output" == *"reports/milestone-N-verifier.md"* ]]
  [[ "$output" == *"ONLY"* ]]
  [[ "$output" == *"done"* ]]
  [[ "$output" == *"approve"* ]]
}

@test "should include the inter-milestone verification gate" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Inter-milestone verification gate"* ]]
  [[ "$output" == *"git diff main"* ]]
  [[ "$output" == *"ABORT"* ]]
}

@test "should include the invariants file for the Final Integration oracle" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"invariants.md"* ]]
  [[ "$output" == *"cross-milestone oracle"* ]]
}

@test "should keep supervisor context lean (no milestone bodies inlined)" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Build a test thing"* ]]
  [[ "$output" != *"Add the feature"* ]]
}

@test "status flip to executing is atomic (no leftover temp file)" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  grep -q "status: executing" .claude/vader/plan.local.md
  # No leftover temp files from the atomic write
  ! ls .claude/vader/plan.local.md.tmp.* 2>/dev/null
}

@test "should persist a Branch/PR structural anchor after each milestone" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch/PR"* ]]
  [[ "$output" == *"branch name and PR URL"* ]]
}

@test "should include checkpoint in the prompt output" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"CHECKPOINT"* ]]
  [[ "$output" == *"idle"* ]]
}

@test "should include crash checkpointing instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Crash checkpointing"* ]]
  [[ "$output" == *"executor_done"* ]]
  [[ "$output" == *"verifier_approved"* ]]
}

@test "should include concurrency control instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Concurrency control"* ]]
  [[ "$output" == *"sequentially"* ]]
}

@test "should include plan overrides section" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan overrides"* ]]
  [[ "$output" == *"supersede persona defaults"* ]]
}

@test "should include current milestone count in prompt" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"CURRENT MILESTONE: 1 of 2"* ]]
}

@test "should use 1-based milestone indexing in loop instruction" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"current_milestone"* ]]
  [[ "$output" == *"total_milestones"* ]]
}

@test "should create a working branch when create_prs is false" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "test-456"
status: planned
current_milestone: 1
checkpoint: idle
total_milestones: 1
max_iterations: 15
create_prs: false
created_at: "2026-02-23T00:00:00Z"
---
# Plan: No PR Plan

## Scope
Simple plan

## Constraints
- None

## Success Criteria
- Works

## Milestone 1: Simple
Do something simple

### Files
- src/simple.sh (add)

### Success Criteria
- It works
EOF

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch Strategy"* ]]
  [[ "$output" == *"git checkout -b"* ]]
  [[ "$output" != *"git push"* ]]
}

@test "should echo checkpoint value into prompt for resume" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "resume-1"
status: executing
current_milestone: 3
checkpoint: verifier_approved
total_milestones: 5
max_iterations: 15
create_prs: true
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Resume Plan

## Scope
Resume

## Constraints
- None

## Success Criteria
- Works

## Milestone 3: Mid
Mid milestone

### Files
- src/mid.sh (add)

### Success Criteria
- Works
EOF

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"CURRENT MILESTONE: 3 of 5"* ]]
  [[ "$output" == *"CHECKPOINT: verifier_approved"* ]]
}

@test "should echo executor_done checkpoint into prompt" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "resume-2"
status: executing
current_milestone: 2
checkpoint: executor_done
total_milestones: 4
max_iterations: 15
create_prs: false
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Resume Two

## Scope
Resume

## Constraints
- None

## Success Criteria
- Works

## Milestone 2: Second
Second milestone

### Files
- src/second.sh (add)

### Success Criteria
- Works
EOF

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"CHECKPOINT: executor_done"* ]]
}

@test "should migrate 0-based current_milestone to 1 in state file" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "legacy"
status: executing
current_milestone: 0
total_milestones: 3
max_iterations: 15
create_prs: false
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Legacy Plan

## Scope
Legacy

## Constraints
- None

## Success Criteria
- Works

## Milestone 1: First
First milestone

### Files
- src/first.sh (add)

### Success Criteria
- Works
EOF

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  grep -q "current_milestone: 1" .claude/vader/plan.local.md
  grep -q "checkpoint: idle" .claude/vader/plan.local.md
  [[ "$output" == *"CURRENT MILESTONE: 1 of 3"* ]]
}

@test "should add checkpoint when missing and set to idle" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "no-checkpoint"
status: executing
current_milestone: 2
total_milestones: 3
max_iterations: 15
create_prs: true
created_at: "2026-02-23T00:00:00Z"
---
# Plan: No Checkpoint

## Scope
No checkpoint

## Constraints
- None

## Success Criteria
- Works

## Milestone 2: Second
Second milestone

### Files
- src/second.sh (add)

### Success Criteria
- Works
EOF

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  grep -q "checkpoint: idle" .claude/vader/plan.local.md
}

@test "should echo existing work_branch into prompt" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "work-branch"
status: executing
current_milestone: 2
checkpoint: idle
work_branch: vader/1700000000
total_milestones: 3
max_iterations: 15
create_prs: false
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Work Branch Plan

## Scope
Work branch

## Constraints
- None

## Success Criteria
- Works

## Milestone 2: Second
Second milestone

### Files
- src/second.sh (add)

### Success Criteria
- Works
EOF

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"WORK BRANCH: vader/1700000000"* ]]
}

@test "should instruct fix loop to reset checkpoint on needs-fix" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"reset checkpoint to \`idle\`"* ]]
}

@test "should guard commit against clean tree on resume" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"git status --short"* ]]
  [[ "$output" == *"skip the commit"* ]]
}

@test "should emit push and PR commands when create_prs is true" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"git push -u origin vader/"* ]]
  [[ "$output" == *"gh pr create"* ]]
  [[ "$output" == *"--base main"* ]]
}

@test "should include final_integration checkpoint value" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"final_integration"* ]]
}

@test "should instruct dirty-tree handling on idle resume" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"git status --short"* ]]
  [[ "$output" == *"partial uncommitted edits"* ]]
}

@test "checkpoint update sed replaces value atomically in frontmatter only" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "sed-1"
status: executing
current_milestone: 1
checkpoint: idle
total_milestones: 2
max_iterations: 15
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Sed Plan
body mentions checkpoint: idle but is not frontmatter
EOF

  sed "/^---$/,/^---$/{ /^---$/!s/^checkpoint: .*/checkpoint: executor_done/; }" .claude/vader/plan.local.md > /tmp/sedout.$$
  mv /tmp/sedout.$$ .claude/vader/plan.local.md

  # frontmatter checkpoint updated
  grep -q "^checkpoint: executor_done$" .claude/vader/plan.local.md
  # body text unchanged
  grep -q "body mentions checkpoint: idle but is not frontmatter" .claude/vader/plan.local.md
  # no temp file left
  ! ls /tmp/sedout.$$ 2>/dev/null
}

@test "checkpoint update sed inserts missing field before closing frontmatter" {
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
session_id: "sed-2"
status: executing
current_milestone: 2
total_milestones: 3
max_iterations: 15
created_at: "2026-02-23T00:00:00Z"
---
# Plan: Sed Insert Plan
EOF

  awk -v key="checkpoint" -v value="idle" '
    /^---$/ { dashes++; if (dashes==2) { print key": "value } }
    { print }
  ' .claude/vader/plan.local.md > /tmp/sedins.$$
  mv /tmp/sedins.$$ .claude/vader/plan.local.md

  # inserted before the body marker
  grep -q "^checkpoint: idle$" .claude/vader/plan.local.md
  # still two frontmatter dashes
  [[ "$(grep -c '^---$' .claude/vader/plan.local.md)" -eq 2 ]]
  # body intact
  grep -q "# Plan: Sed Insert Plan" .claude/vader/plan.local.md
  ! ls /tmp/sedins.$$ 2>/dev/null
}
