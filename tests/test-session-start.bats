#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../hooks/session-start.sh"
  PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
  VERSION=$(jq -r .version "$PLUGIN_ROOT/.claude-plugin/plugin.json")
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "should always announce the plugin version" {
  # Arrange
  local input='{"permission_mode": "bypassPermissions"}'

  # Act
  run bash -c "echo '$input' | '$SCRIPT'"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Vader v${VERSION}"* ]]
}

@test "should not add permission nudge when no plan exists" {
  # Arrange
  local input='{"permission_mode": "default"}'

  # Act
  run bash -c "echo '$input' | '$SCRIPT'"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" != *"dangerously-skip-permissions"* ]]
}

@test "should add permission nudge when plan exists and not in bypass mode" {
  # Arrange
  mkdir -p .claude/vader
  echo "---" > .claude/vader/plan.local.md
  local input='{"permission_mode": "default"}'

  # Act
  run bash -c "echo '$input' | '$SCRIPT'"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" == *"Vader v${VERSION}"* ]]
  [[ "$output" == *"dangerously-skip-permissions"* ]]
}

@test "should not add permission nudge when plan exists but bypass mode active" {
  # Arrange
  mkdir -p .claude/vader
  echo "---" > .claude/vader/plan.local.md
  local input='{"permission_mode": "bypassPermissions"}'

  # Act
  run bash -c "echo '$input' | '$SCRIPT'"

  # Assert
  [ "$status" -eq 0 ]
  [[ "$output" != *"dangerously-skip-permissions"* ]]
}
