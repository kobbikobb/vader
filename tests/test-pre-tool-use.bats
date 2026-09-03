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

# Payload goes through a file so command text with quotes survives verbatim.
run_hook() {
  jq -nc --arg t "$1" --arg c "${2-}" '{tool_name:$t,tool_input:{command:$c}}' > payload.json
  run bash -c "'$SCRIPT' < payload.json"
}

decision() {
  echo "$output" | jq -r .hookSpecificOutput.permissionDecision
}

@test "should allow the edit when no plan exists" {
  run_hook Edit

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should deny every file-editing tool while a saved plan has not started" {
  write_plan planned

  for tool in Edit Write MultiEdit NotebookEdit; do
    run_hook "$tool"

    [ "$status" -eq 0 ]
    [ "$(decision)" == "deny" ] || { echo "$tool was allowed"; return 1; }
  done

  [[ "$output" == *"/vader:exec"* ]]
}

@test "should allow the edit once execution has started" {
  write_plan executing

  run_hook Edit

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow the edit when the plan is done" {
  write_plan done

  run_hook Edit

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should read the plan from VADER_STATE_DIR" {
  mkdir -p .cursor/vader
  printf -- '---\nstatus: planned\n---\n' > .cursor/vader/plan.local.md
  export VADER_STATE_DIR=.cursor/vader

  run_hook Edit

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should deny an unrelated bash command while the plan has not started" {
  write_plan planned

  run_hook Bash 'cp /tmp/x src/app.ts'

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should allow vader's own scripts to run" {
  write_plan planned

  run_hook Bash '"${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh"'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow a vader script that takes arguments" {
  write_plan planned

  run_hook Bash '"${CLAUDE_PLUGIN_ROOT}/scripts/refine-picker.sh" list'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow plan prose that contains shell metacharacters" {
  write_plan planned

  run_hook Bash '"${CLAUDE_PLUGIN_ROOT}/scripts/setup-plan.sh" "Auth & billing" "keep API stable; ship it" "c" "s" '"'"'[{"goal":"a|b"}]'"'"' 3 true'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should allow the cancel command to remove the plan" {
  write_plan planned

  run_hook Bash 'rm -f "${VADER_STATE_DIR:-.claude/vader}/plan.local.md"'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should deny a chained command that name-drops the plan file" {
  write_plan planned

  run_hook Bash 'touch src/app.ts; echo plan.local.md'

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should deny a command that only names the plan file in an argument" {
  write_plan planned

  run_hook Bash 'cp plan.local.md src/app.ts'

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should deny a second line smuggled after a vader invocation" {
  write_plan planned

  run_hook Bash '"${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh"
touch src/app.ts'

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should deny a redirect appended to a vader invocation" {
  write_plan planned

  run_hook Bash '"${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh" > src/app.ts'

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

  run_hook Edit

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "should deny on a CRLF plan file that has not started" {
  printf -- '---\r\nstatus: planned\r\n---\r\n' > .claude/vader/plan.local.md

  run_hook Edit

  [ "$status" -eq 0 ]
  [ "$(decision)" == "deny" ]
}

@test "should ignore a CRLF status line outside the frontmatter" {
  printf -- '---\r\nstatus: executing\r\n---\r\n\r\nstatus: planned\r\n' > .claude/vader/plan.local.md

  run_hook Edit

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
