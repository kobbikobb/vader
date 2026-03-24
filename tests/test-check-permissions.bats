#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-permissions.sh"
}

@test "should output bypassPermissions when env var is set" {
  CLAUDE_PERMISSION_MODE=bypassPermissions run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "bypassPermissions" ]
}

@test "should output default when env var is not set and no matching process" {
  unset CLAUDE_PERMISSION_MODE
  # Override pgrep to ensure it doesn't find anything
  pgrep() { return 1; }
  export -f pgrep
  run "$SCRIPT"
  unset -f pgrep

  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

@test "should output default when env var is empty and no matching process" {
  # Override pgrep to ensure it doesn't find anything
  pgrep() { return 1; }
  export -f pgrep
  CLAUDE_PERMISSION_MODE="" run "$SCRIPT"
  unset -f pgrep

  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}
