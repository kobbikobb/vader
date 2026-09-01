#!/usr/bin/env bats

setup() {
  PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
}

@test "cursor plugin manifest is valid json with required name" {
  run jq -er '.name' "$PLUGIN_ROOT/.cursor-plugin/plugin.json"
  [ "$status" -eq 0 ]
  [ "$output" == "vader" ]
}

@test "cursor plugin manifest declares agents and commands dirs" {
  run jq -e '.agents == ".cursor-plugin/agents" and .commands == ".cursor-plugin/commands"' "$PLUGIN_ROOT/.cursor-plugin/plugin.json"
  [ "$status" -eq 0 ]
}

@test "every agent wrapper has name and description frontmatter" {
  for f in "$PLUGIN_ROOT"/.cursor-plugin/agents/*.md; do
    run bash -c "sed -n '1,4p' '$f' | grep -q '^---$' && sed -n '2,4p' '$f' | grep -q '^name:' && sed -n '2,4p' '$f' | grep -q '^description:'"
    [ "$status" -eq 0 ] || echo "missing frontmatter: $f"
    [ "$status" -eq 0 ]
  done
}

@test "every agent wrapper references an existing persona" {
  for f in "$PLUGIN_ROOT"/.cursor-plugin/agents/*.md; do
    persona=$(grep -o 'agents/[^`]*\.md' "$f" | head -1)
    [ -n "$persona" ] || { echo "no persona reference: $f"; return 1; }
    [ -f "$PLUGIN_ROOT/$persona" ] || { echo "missing persona: $persona"; return 1; }
  done
}

@test "read-only agents declare readonly frontmatter" {
  for name in vader-chunker vader-discusser vader-plan-checker vader-refine-verifier; do
    f="$PLUGIN_ROOT/.cursor-plugin/agents/${name#vader-}.md"
    run grep -q "readonly: true" "$f"
    [ "$status" -eq 0 ] || echo "missing readonly: $f"
    [ "$status" -eq 0 ]
  done
}

@test "every command has name and description frontmatter" {
  for f in "$PLUGIN_ROOT"/.cursor-plugin/commands/*.md; do
    run bash -c "sed -n '1,4p' '$f' | grep -q '^---$' && sed -n '2,4p' '$f' | grep -q '^name:' && sed -n '2,4p' '$f' | grep -q '^description:'"
    [ "$status" -eq 0 ] || echo "missing frontmatter: $f"
    [ "$status" -eq 0 ]
  done
}

@test "vader-exec command references vader-executor and vader-verifier agents" {
  run grep -q "vader-executor" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-exec.md"
  [ "$status" -eq 0 ]
  run grep -q "vader-verifier" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-exec.md"
  [ "$status" -eq 0 ]
}

@test "commands reference setup scripts that exist" {
  run grep -q "scripts/setup-exec.sh" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-exec.md"
  [ "$status" -eq 0 ]
  run grep -q "scripts/setup-plan.sh" "$PLUGIN_ROOT/.cursor-plugin/commands/vader.md"
  [ "$status" -eq 0 ]
  run grep -q "scripts/scan-worktrees.sh" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-status.md"
  [ "$status" -eq 0 ]
  run grep -q "scripts/setup-refine.sh" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-refine.md"
  [ "$status" -eq 0 ]
  run grep -q "scripts/refine-picker.sh" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-refine.md"
  [ "$status" -eq 0 ]
}

@test "claude and cursor manifests share the same version" {
  local claude cursor
  claude=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
  cursor=$(jq -r '.version' "$PLUGIN_ROOT/.cursor-plugin/plugin.json")
  [ "$claude" == "$cursor" ]
}