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
current_milestone: 0
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

@test "should write prompt file referencing state file instead of inlining plan" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  PROMPT_CONTENT=$(cat .claude/vader/prompt.local.md)
  [[ "$PROMPT_CONTENT" == *"executing a vader plan"* ]]
  [[ "$PROMPT_CONTENT" == *"Read the state file"* ]]
  [[ "$PROMPT_CONTENT" == *"current_milestone"* ]]
  # Plan body should NOT be inlined in the prompt
  [[ "$PROMPT_CONTENT" != *"Milestone 1: Setup"* ]]
  [[ "$PROMPT_CONTENT" != *"Milestone 2: Feature"* ]]
}

@test "should output prompt file path" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *".claude/vader/prompt.local.md"* ]]
}

@test "should update status to executing" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  grep -q "status: executing" .claude/vader/plan.local.md
}

@test "should fail when plan status is done" {
  create_plan_file
  sed -i.bak 's/status: planned/status: done/' .claude/vader/plan.local.md

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"already completed"* ]]
}

@test "should include completion promise instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  PROMPT_CONTENT=$(cat .claude/vader/prompt.local.md)
  [[ "$PROMPT_CONTENT" == *"Hurra Vader has Triumphed"* ]]
}

@test "should include milestone workflow instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  PROMPT_CONTENT=$(cat .claude/vader/prompt.local.md)
  [[ "$PROMPT_CONTENT" == *"commit"* ]]
  [[ "$PROMPT_CONTENT" == *"current_milestone"* ]]
}
