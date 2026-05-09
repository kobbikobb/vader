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

@test "should reject milestones with more than 5 scenarios" {
  # Arrange: a milestone with 6 scenarios — over the cap
  SIX_SCENARIOS='[{"name":"s1","check":"c1"},{"name":"s2","check":"c2"},{"name":"s3","check":"c3"},{"name":"s4","check":"c4"},{"name":"s5","check":"c5"},{"name":"s6","check":"c6"}]'
  MILESTONES='[{"name":"Big","scope":"Too much","files":[],"scenarios":'"$SIX_SCENARIOS"'}]'

  # Act
  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  # Assert
  [ "$status" -ne 0 ]
  [[ "$output" == *"exceed 5 scenarios"* ]]
  [[ "$output" == *"Big: 6 scenarios"* ]]
  [ ! -f ".claude/vader/plan.local.md" ]
}

@test "should accept exactly 5 scenarios" {
  FIVE_SCENARIOS='[{"name":"s1","check":"c1"},{"name":"s2","check":"c2"},{"name":"s3","check":"c3"},{"name":"s4","check":"c4"},{"name":"s5","check":"c5"}]'
  MILESTONES='[{"name":"OnTheLine","scope":"At cap","files":[],"scenarios":'"$FIVE_SCENARIOS"'}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -eq 0 ]
  [ -f ".claude/vader/plan.local.md" ]
}

@test "should allow override of scenario cap via VADER_ALLOW_LARGE_MILESTONES" {
  SIX_SCENARIOS='[{"name":"s1","check":"c1"},{"name":"s2","check":"c2"},{"name":"s3","check":"c3"},{"name":"s4","check":"c4"},{"name":"s5","check":"c5"},{"name":"s6","check":"c6"}]'
  MILESTONES='[{"name":"Big","scope":"Too much","files":[],"scenarios":'"$SIX_SCENARIOS"'}]'

  VADER_ALLOW_LARGE_MILESTONES=1 run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -eq 0 ]
  [ -f ".claude/vader/plan.local.md" ]
}

@test "should report all oversized milestones, not just the first" {
  SIX='[{"name":"s1","check":"c"},{"name":"s2","check":"c"},{"name":"s3","check":"c"},{"name":"s4","check":"c"},{"name":"s5","check":"c"},{"name":"s6","check":"c"}]'
  SEVEN='[{"name":"s1","check":"c"},{"name":"s2","check":"c"},{"name":"s3","check":"c"},{"name":"s4","check":"c"},{"name":"s5","check":"c"},{"name":"s6","check":"c"},{"name":"s7","check":"c"}]'
  MILESTONES='[{"name":"First","scope":"x","files":[],"scenarios":'"$SIX"'},{"name":"Second","scope":"y","files":[],"scenarios":'"$SEVEN"'}]'

  run "$SCRIPT" "Test" "Scope" "Constraints" "Criteria" "$MILESTONES" 10

  [ "$status" -ne 0 ]
  [[ "$output" == *"2 milestone(s) exceed"* ]]
  [[ "$output" == *"First: 6 scenarios"* ]]
  [[ "$output" == *"Second: 7 scenarios"* ]]
}
