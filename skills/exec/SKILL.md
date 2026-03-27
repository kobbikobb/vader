---
name: exec
description: "Execute the current vader plan via ralph-wiggum loop"
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh:*)
  - Bash(git:*)
  - Bash(gh:*)
  - Read(.claude/vader/plan.local.md)
  - Read(.claude/vader/prompt.local.md)
---

# Vader Execution

Execute the current vader plan through a ralph-wiggum loop.

## Step 1: Check Permissions

Run the permissions check:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh"
```

If the output is NOT `bypassPermissions`, warn the user:

> Vader works best with `--dangerously-skip-permissions` to avoid permission prompts interrupting the loop.
> Consider restarting with: `claude --dangerously-skip-permissions`

Ask if they want to continue anyway. If not, stop.

## Step 2: Read Plan

Read the plan file:

```text
.claude/vader/plan.local.md
```

If the file does not exist, tell the user to run `/vader` first and stop.

## Step 3: Compose Prompt

Run the setup script to compose the ralph-wiggum prompt:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh"
```

The output is the composed prompt text directly.

## Step 4: Launch Ralph Loop

Read the `max_iterations` from the plan file frontmatter.

Try to invoke the ralph-wiggum loop using the Skill tool:

- skill: `ralph-loop:ralph-loop`
- args: `<prompt-from-step-3> --max-iterations <max_iterations> --completion-promise 'Hurra Vader has Triumphed'`

### Fallback: Direct Execution

If the `ralph-loop:ralph-loop` skill is not available (skill not found error), execute the plan directly:

1. Read `.claude/vader/plan.local.md` for the full plan
2. Work through each milestone sequentially following the prompt instructions from Step 3
3. For each milestone: implement, test, lint/format, commit, update state file
4. After all milestones: update status to "done" and output `<promise>Hurra Vader has Triumphed</promise>`

The direct execution mode works identically to the ralph-wiggum loop but runs inline in the current session.
