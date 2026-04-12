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

@test "should output prompt to stdout referencing state file instead of inlining plan" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"executing a vader plan"* ]]
  [[ "$output" == *"Read the state file"* ]]
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

@test "should include executor agent persona" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Executor"* ]]
  [[ "$output" == *"Implement a single milestone"* ]]
}

@test "should include verifier agent persona" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Verifier"* ]]
  [[ "$output" == *"Validate that a milestone achieved its goal"* ]]
}

@test "should include max retry instructions" {
  create_plan_file

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Maximum 3"* ]]
}
