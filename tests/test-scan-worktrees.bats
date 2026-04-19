#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/scan-worktrees.sh"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init -q -b main
  git config user.email test@example.com
  git config user.name Test
  git commit --allow-empty -q -m "initial"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "should print nothing when no vader state exists" {
  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should emit refine row when state file exists" {
  # Arrange
  mkdir -p .claude/vader
  cat > .claude/vader/refine.local.md <<'EOF'
---
status: reviewing
branch: "feature"
resolved_topics: 1
total_topics: 3
---
EOF

  # Act
  run "$SCRIPT"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"refine"* ]]
  [[ "$output" == *"reviewing"* ]]
  [[ "$output" == *"1/3"* ]]
  [[ "$output" == *"*"* ]]
}

@test "should emit plan row when state file exists" {
  # Arrange
  mkdir -p .claude/vader
  cat > .claude/vader/plan.local.md <<'EOF'
---
status: executing
current_milestone: 2
total_milestones: 5
---
EOF

  # Act
  run "$SCRIPT"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"plan"* ]]
  [[ "$output" == *"executing"* ]]
  [[ "$output" == *"2/5"* ]]
}

@test "should scan a linked worktree" {
  # Arrange
  echo "hi" > a.txt
  git add a.txt
  git commit -q -m "seed"
  git branch feature
  local wt
  wt=$(mktemp -d)
  rm -rf "$wt"
  git worktree add -q "$wt" feature
  mkdir -p "$wt/.claude/vader"
  cat > "$wt/.claude/vader/refine.local.md" <<'EOF'
---
status: reviewing
branch: "feature"
resolved_topics: 0
total_topics: 2
---
EOF

  # Act
  run "$SCRIPT"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"feature"* ]]
  [[ "$output" == *"0/2"* ]]

  git worktree remove -f "$wt" || rm -rf "$wt"
}

@test "should skip rows with status done" {
  # Arrange
  mkdir -p .claude/vader
  cat > .claude/vader/refine.local.md <<'EOF'
---
status: done
branch: "feature"
resolved_topics: 3
total_topics: 3
---
EOF
  cat > .claude/vader/plan.local.md <<'EOF'
---
status: done
current_milestone: 5
total_milestones: 5
---
EOF

  # Act
  run "$SCRIPT"

  # Assert
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
