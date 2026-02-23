---
name: exec
description: "Execute the current vader plan via ralph-wiggum loop"
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh:*)
  - Read(.claude/vader/plan.local.md)
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

Capture the output - this is the composed prompt.

## Step 4: Launch Ralph Loop

Read the `max_iterations` from the plan file frontmatter.

Invoke the ralph-wiggum loop using the Skill tool:

- skill: `ralph-wiggum:ralph-loop`
- args: `<composed-prompt> --max-iterations <max_iterations> --completion-promise 'Hurra Vader has Triumphed'`

The ralph-wiggum loop will handle the rest. Claude will work through milestones sequentially,
committing each one and updating the state file until all milestones are complete.
