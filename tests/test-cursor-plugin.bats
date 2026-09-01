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
    run sed -n '1,5p' "$f"
    [[ "$output" == *"---"* ]] || { echo "missing open fence: $f"; return 1; }
    [[ "$output" == *"name:"* ]] || { echo "missing name: $f"; return 1; }
    [[ "$output" == *"description:"* ]] || { echo "missing description: $f"; return 1; }
  done
}

@test "every agent wrapper references an existing persona" {
  for f in "$PLUGIN_ROOT"/.cursor-plugin/agents/*.md; do
    persona=$(grep -o 'agents/[^`]*\.md' "$f" | head -1)
    [ -n "$persona" ] || { echo "no persona reference: $f"; return 1; }
    [ -f "$PLUGIN_ROOT/$persona" ] || { echo "missing persona: $persona"; return 1; }
  done
}

@test "read-only agents declare readonly only in frontmatter" {
  for name in researcher chunker discusser plan-checker refine-verifier; do
    f="$PLUGIN_ROOT/.cursor-plugin/agents/$name.md"
    run awk 'NR > 1 && /^---$/ { closed=1; exit } /^[[:space:]]*readonly:[[:space:]]*true[[:space:]]*$/ { found=1 } END { exit !(closed && found) }' "$f"
    [ "$status" -eq 0 ] || { echo "missing readonly in frontmatter: $f"; return 1; }
  done
}

@test "every command has name and description frontmatter" {
  for f in "$PLUGIN_ROOT"/.cursor-plugin/commands/*.md; do
    run sed -n '1,5p' "$f"
    [[ "$output" == *"---"* ]] || { echo "missing open fence: $f"; return 1; }
    [[ "$output" == *"name:"* ]] || { echo "missing name: $f"; return 1; }
    [[ "$output" == *"description:"* ]] || { echo "missing description: $f"; return 1; }
  done
}

@test "vader-exec command references vader-executor and vader-verifier agents" {
  run grep -q "vader-executor" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-exec.md"
  [ "$status" -eq 0 ]
  run grep -q "vader-verifier" "$PLUGIN_ROOT/.cursor-plugin/commands/vader-exec.md"
  [ "$status" -eq 0 ]
}

@test "commands reference scripts that exist" {
  for script in setup-exec.sh setup-plan.sh scan-worktrees.sh setup-refine.sh refine-picker.sh; do
    [ -x "$PLUGIN_ROOT/scripts/$script" ] || [ -f "$PLUGIN_ROOT/scripts/$script" ] || {
      echo "missing script: scripts/$script"; return 1; }
  done
}

@test "claude and cursor manifests share the same version" {
  local claude cursor marketplace
  claude=$(jq -r '.version' "$PLUGIN_ROOT/.claude-plugin/plugin.json")
  cursor=$(jq -r '.version' "$PLUGIN_ROOT/.cursor-plugin/plugin.json")
  marketplace=$(jq -r '.plugins[0].version' "$PLUGIN_ROOT/.claude-plugin/marketplace.json")
  [ "$claude" == "$cursor" ]
  [ "$claude" == "$marketplace" ]
}
