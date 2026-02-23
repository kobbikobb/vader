#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-permissions.sh"
}

@test "should output bypassPermissions when env var is set" {
  CLAUDE_PERMISSION_MODE=bypassPermissions run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "bypassPermissions" ]
}

@test "should output default when env var is not set" {
  unset CLAUDE_PERMISSION_MODE
  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == "default" || "$output" == "bypassPermissions" ]]
}

@test "should output default when env var is empty" {
  CLAUDE_PERMISSION_MODE="" run "$SCRIPT"

  [ "$status" -eq 0 ]
  [[ "$output" == "default" || "$output" == "bypassPermissions" ]]
}
