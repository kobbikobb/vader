#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../hooks/pre-tool-use.sh"
  HOOKS_JSON="$BATS_TEST_DIRNAME/../hooks/hooks.json"
  CANCEL_SKILL="$BATS_TEST_DIRNAME/../skills/cancel/SKILL.md"
  EDIT='{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}'
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

bash_input() {
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"
}

decision() {
  echo "$output" | jq -r .hookSpecificOutput.permissionDecision
}

@test "should allow the edit when no plan exists" {
  run bash -c "printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should deny the edit while a saved plan has not started" {
  write_plan planned

  run bash -c "printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
  [[ "$output" == *"/vader:exec"* ]]
}

@test "should allow the edit once execution has started" {
  write_plan executing

  run bash -c "printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow the edit when the plan is done" {
  write_plan done

  run bash -c "printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should read the plan from VADER_STATE_DIR" {
  mkdir -p .cursor/vader
  printf -- '---\nstatus: planned\n---\n' > .cursor/vader/plan.local.md

  run bash -c "VADER_STATE_DIR=.cursor/vader; export VADER_STATE_DIR; printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should deny an unrelated bash command while the plan has not started" {
  write_plan planned
  local input
  input=$(bash_input 'cp /tmp/x src/app.ts')

  run bash -c "printf '%s' '$input' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should allow vader's own scripts to run" {
  write_plan planned
  local input
  input=$(bash_input '\"${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh\"')

  run bash -c "printf '%s' '$input' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow the cancel command to remove the plan" {
  write_plan planned
  local input
  input=$(bash_input 'rm -f \"${VADER_STATE_DIR:-.claude/vader}/plan.local.md\"')

  run bash -c "printf '%s' '$input' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should deny a chained command that name-drops the plan file" {
  write_plan planned
  local input
  input=$(bash_input 'touch src/app.ts; echo plan.local.md')

  run bash -c "printf '%s' '$input' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should allow a payload whose tool cannot be read" {
  write_plan planned

  run bash -c "printf '%s' 'not json' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should ignore a status line outside the frontmatter" {
  printf -- '---\nstatus: executing\n---\n\n## Milestone 1\n\nstatus: planned\n' > .claude/vader/plan.local.md

  run bash -c "printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should still match a status line ending in a carriage return" {
  printf -- '---\r\nstatus: planned\r\n---\r\n' > .claude/vader/plan.local.md

  run bash -c "printf '%s' '$EDIT' | '$SCRIPT'"

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should register the hook for every tool that can write a file" {
  run jq -er '.hooks.PreToolUse[0] | select(.hooks[0].command | endswith("/hooks/pre-tool-use.sh")) | .matcher' "$HOOKS_JSON"

  [ "$status" -eq 0 ]
  for tool in Edit Write MultiEdit NotebookEdit Bash; do
    [[ "$output" == *"$tool"* ]] || { echo "matcher misses $tool: $output"; return 1; }
  done
}

@test "should keep the cancel command on the same state dir as the hook" {
  run grep -c 'VADER_STATE_DIR:-.claude/vader}/plan.local.md' "$CANCEL_SKILL"

  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}
