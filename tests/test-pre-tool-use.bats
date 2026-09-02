#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../hooks/pre-tool-use.sh"
  HOOKS_JSON="$BATS_TEST_DIRNAME/../hooks/hooks.json"
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  mkdir -p .claude/vader
}

teardown() {
  rm -rf "$TEST_DIR"
}

write_plan() {
  printf -- '---\nsession_id: "abc"\nstatus: %s\n---\n' "$1" > .claude/vader/plan.local.md
}

@test "should allow the edit when no plan exists" {
  run bash -c "echo '{}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should deny the edit while a saved plan has not started" {
  write_plan planned

  run bash -c "echo '{}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .hookSpecificOutput.permissionDecision)" == "deny" ]
  [[ "$output" == *"/vader:exec"* ]]
}

@test "should allow the edit once execution has started" {
  write_plan executing

  run bash -c "echo '{}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow the edit when the plan is done" {
  write_plan done

  run bash -c "echo '{}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should read the plan from VADER_STATE_DIR" {
  mkdir -p .cursor/vader
  printf -- '---\nstatus: planned\n---\n' > .cursor/vader/plan.local.md

  run bash -c "VADER_STATE_DIR=.cursor/vader; export VADER_STATE_DIR; echo '{}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .hookSpecificOutput.permissionDecision)" == "deny" ]
}

@test "should deny a bash command that writes a file" {
  write_plan planned

  run bash -c "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat > src/app.ts <<EOF\"}}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r .hookSpecificOutput.permissionDecision)" == "deny" ]
}

@test "should allow a read-only bash command" {
  write_plan planned

  run bash -c "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status --short 2>/dev/null\"}}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should ignore a status line outside the frontmatter" {
  printf -- '---\nstatus: executing\n---\n\n## Milestone 1\n\nstatus: planned\n' > .claude/vader/plan.local.md

  run bash -c "echo '{}' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should register the hook for every tool that can write a file" {
  run jq -er '.hooks.PreToolUse[0] | select(.hooks[0].command | endswith("/hooks/pre-tool-use.sh")) | .matcher' "$HOOKS_JSON"

  [ "$status" -eq 0 ]
  for tool in Edit Write MultiEdit NotebookEdit Bash; do
    [[ "$output" == *"$tool"* ]] || { echo "matcher misses $tool: $output"; return 1; }
  done
}
