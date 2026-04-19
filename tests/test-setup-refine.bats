#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/setup-refine.sh"
  TEST_DIR=$(mktemp -d)
  STUB_DIR=$(mktemp -d)
  # Stub gh outside the test repo so it stays untracked-free
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
  git commit --allow-empty -q -m "initial"
}

teardown() {
  rm -rf "$TEST_DIR" "$STUB_DIR"
}

@test "should abort when on default branch" {
  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"switch to a feature branch"* ]]
}

@test "should abort when no changes vs base" {
  git checkout -q -b feature

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to refine"* ]]
}

@test "should abort when working tree is dirty" {
  git checkout -q -b feature
  echo "hello" > a.txt
  git add a.txt
  git commit -q -m "add a"
  echo "dirty" > b.txt

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"working tree is dirty"* ]]
}

@test "should write state file on clean feature branch with commits" {
  git checkout -q -b feature
  echo "hello" > a.txt
  git add a.txt
  git commit -q -m "add a"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -f ".claude/vader/refine.local.md" ]
  grep -q 'status: reviewing' .claude/vader/refine.local.md
  grep -q 'branch: "feature"' .claude/vader/refine.local.md
  grep -q 'base: "main"' .claude/vader/refine.local.md
  grep -q 'large_diff: false' .claude/vader/refine.local.md
  [[ "$output" == *"resuming: false"* ]]
}

@test "should mark large_diff true when threshold exceeded" {
  git checkout -q -b feature
  seq 1 10 > a.txt
  git add a.txt
  git commit -q -m "add a"
  export VADER_LARGE_DIFF_THRESHOLD=5

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  grep -q 'large_diff: true' .claude/vader/refine.local.md
  [[ "$output" == *"large_diff: true"* ]]
}

@test "should resume when called again on same branch with same base_sha" {
  git checkout -q -b feature
  echo "hello" > a.txt
  git add a.txt
  git commit -q -m "add a"
  "$SCRIPT" >/dev/null
  # Mutate state to prove resume preserves it
  printf '\nmarker-line\n' >> .claude/vader/refine.local.md

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Resuming"* ]]
  [[ "$output" == *"resuming: true"* ]]
  grep -q 'marker-line' .claude/vader/refine.local.md
}

@test "should not abort when only .claude/vader/ has untracked files" {
  git checkout -q -b feature
  echo "hello" > a.txt
  git add a.txt
  git commit -q -m "add a"
  "$SCRIPT" >/dev/null
  # Writing extra stuff inside .claude/vader should NOT count as dirty
  echo "extra" > .claude/vader/scratch.txt

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Resuming"* ]]
}

@test "should abort when a tracked file has unstaged modifications" {
  git checkout -q -b feature
  echo "hello" > a.txt
  git add a.txt
  git commit -q -m "add a"
  echo "changed" > a.txt

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [[ "$output" == *"working tree is dirty"* ]]
}

@test "should overwrite state when branch changed" {
  git checkout -q -b feature-a
  echo "hello" > a.txt
  git add a.txt
  git commit -q -m "add a"
  "$SCRIPT" >/dev/null

  git checkout -q main
  git checkout -q -b feature-b
  echo "other" > b.txt
  git add b.txt
  git commit -q -m "add b"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == *"resuming: false"* ]]
  grep -q 'branch: "feature-b"' .claude/vader/refine.local.md
}
