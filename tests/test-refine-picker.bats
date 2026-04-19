#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/refine-picker.sh"
  TEST_DIR=$(mktemp -d)
  STUB_DIR=$(mktemp -d)
  # Stub gh so tests stay hermetic
  cat > "$STUB_DIR/gh" <<'GH'
#!/bin/bash
exit 1
GH
  chmod +x "$STUB_DIR/gh"
  export PATH="$STUB_DIR:$PATH"
  cd "$TEST_DIR"
  git init -q -b main
  git config user.email test@example.com
  git config user.name Test
  echo "seed" > seed.txt
  git add seed.txt
  git commit -q -m "initial"
}

teardown() {
  rm -rf "$TEST_DIR" "$STUB_DIR"
}

@test "should require a subcommand" {
  run "$SCRIPT"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "should list local feature branches with unmerged commits" {
  # Arrange
  git checkout -q -b feat-a
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "add a"
  git checkout -q main

  # Act
  run "$SCRIPT" list

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat-a"* ]]
}

@test "should skip default branch in list" {
  # Arrange
  git checkout -q -b feat
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "add a"

  # Act
  run "$SCRIPT" list

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" != *"main	"* ]]
}

@test "should resolve returns NONE and suggested path when no worktree exists" {
  git checkout -q -b feat
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "add a"
  git checkout -q main

  run "$SCRIPT" resolve feat

  [ "$status" -eq 0 ]
  [[ "$output" == NONE:* ]]
  [[ "$output" == *"-feat"* ]]
}

@test "should resolve returns existing worktree path" {
  # Arrange
  git checkout -q -b feat
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "add a"
  git checkout -q main
  local wt_path="$TEST_DIR/../wt-feat-$$"
  git worktree add -q "$wt_path" feat

  # Act
  run "$SCRIPT" resolve feat

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" != NONE:* ]]
  [[ "$output" == *"wt-feat-$$"* ]]

  git worktree remove -f "$wt_path" || rm -rf "$wt_path"
}

@test "should create a worktree at the given path" {
  # Arrange
  git checkout -q -b feat
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "add a"
  git checkout -q main
  local wt_path="$TEST_DIR/../new-wt-$$"

  # Act
  run "$SCRIPT" create feat "$wt_path"

  # Assert
  [ "$status" -eq 0 ]
  [ -d "$wt_path" ]
  [[ "$output" == *"$wt_path"* ]]

  git worktree remove -f "$wt_path" || rm -rf "$wt_path"
}

@test "should fail to create when path already exists" {
  # Arrange
  git checkout -q -b feat
  echo "x" > a.txt
  git add a.txt
  git commit -q -m "add a"
  local existing="$TEST_DIR/already-there"
  mkdir -p "$existing"

  # Act
  run "$SCRIPT" create feat "$existing"

  # Assert
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}
