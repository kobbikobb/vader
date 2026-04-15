#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/setup-plan.sh"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "should create plan state file with correct frontmatter" {
  MILESTONES='[{"name":"Setup","scope":"Initial setup","files":["src/index.ts (add)"],"success_criteria":["Project builds"]}]'

  run "$SCRIPT" "Test Project" "Build a thing" "- Use TypeScript" "- All tests pass" "$MILESTONES" 15

  [ "$status" -eq 0 ]
  [ -f ".claude/vader/plan.local.md" ]
  grep -q "status: planned" .claude/vader/plan.local.md
  grep -q "current_milestone: 0" .claude/vader/plan.local.md
  grep -q "total_milestones: 1" .claude/vader/plan.local.md
  grep -q "max_iterations: 15" .claude/vader/plan.local.md
}

@test "should write milestone content to plan file" {
  MILESTONES='[{"name":"Setup","scope":"Initial setup","files":["src/index.ts (add)"],"success_criteria":["Project builds"]},{"name":"Feature","scope":"Add feature","files":["src/feature.ts (add)"],"success_criteria":["Feature works"]}]'

  run "$SCRIPT" "Test Project" "Build a thing" "- Use TypeScript" "- All tests pass" "$MILESTONES" 20

  [ "$status" -eq 0 ]
  grep -q "# Plan: Test Project" .claude/vader/plan.local.md
  grep -q "## Milestone 1: Setup" .claude/vader/plan.local.md
  grep -q "## Milestone 2: Feature" .claude/vader/plan.local.md
  grep -q "total_milestones: 2" .claude/vader/plan.local.md
  grep -q "max_iterations: 20" .claude/vader/plan.local.md
}

@test "should fail with invalid milestones JSON" {
  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "not-json" 15

  [ "$status" -ne 0 ]
  [[ "$output" == *"valid JSON"* ]]
}

@test "should fail with empty milestones array" {
  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "[]" 15

  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one milestone"* ]]
}

@test "should fail with non-numeric max_iterations" {
  MILESTONES='[{"name":"Setup","scope":"Setup","files":[],"success_criteria":[]}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" "abc"

  [ "$status" -ne 0 ]
  [[ "$output" == *"positive integer"* ]]
}

@test "should default max_iterations to 15" {
  MILESTONES='[{"name":"Setup","scope":"Setup","files":["f.ts (add)"],"success_criteria":["works"]}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES"

  [ "$status" -eq 0 ]
  grep -q "max_iterations: 15" .claude/vader/plan.local.md
}

@test "should include session_id in frontmatter" {
  MILESTONES='[{"name":"Setup","scope":"Setup","files":[],"success_criteria":[]}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -eq 0 ]
  grep -q "session_id:" .claude/vader/plan.local.md
}

@test "should preserve Arrange/Act/Assert scenarios in plan file" {
  MILESTONES='[{"name":"Auth","scope":"JWT auth","files":["src/auth.ts (add)"],"scenarios":[{"name":"Valid login returns JWT","arrange":"User exists","act":"POST /login","assert":"200 with JWT"}]}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -eq 0 ]
  grep -q "Scenario: Valid login returns JWT" .claude/vader/plan.local.md
  grep -q "Arrange: User exists" .claude/vader/plan.local.md
  grep -q "Act: POST /login" .claude/vader/plan.local.md
  grep -q "Assert: 200 with JWT" .claude/vader/plan.local.md
}

@test "should preserve simple check scenarios for infrastructure milestones" {
  MILESTONES='[{"name":"CI","scope":"Setup CI","files":[".github/workflows/ci.yml (add)"],"scenarios":[{"name":"CI runs on push","check":"Push commit, see workflow run"}]}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -eq 0 ]
  grep -q "Scenario: CI runs on push" .claude/vader/plan.local.md
  grep -q "Check: Push commit, see workflow run" .claude/vader/plan.local.md
}

@test "should fall back to success_criteria if scenarios not provided" {
  MILESTONES='[{"name":"Setup","scope":"Setup","files":[],"success_criteria":["Project builds","Tests pass"]}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -eq 0 ]
  grep -q "Project builds" .claude/vader/plan.local.md
  grep -q "Tests pass" .claude/vader/plan.local.md
}
