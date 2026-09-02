---
name: exec
description: "Execute the current vader plan via direct execution"
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

Execute the current vader plan through the thin-router loop.

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

Note the `reports_dir` from the plan frontmatter. Use it (not a hardcoded
`.claude/vader/reports`) for every report and invariants path so the
paths match what setup-exec.sh composes into the thin-router prompt.

## Step 3: Compose Prompt

Run the setup script to compose the thin-router prompt:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh"
```

The output is the composed prompt text directly. It represents a thin-router prompt: the
running agent holds only the current milestone index and latest verdict, all heavy
content stays in `.claude/vader/reports/` on disk.

## Step 4: Direct Execution

Read the `max_iterations` from the plan file frontmatter.

Follow the thin-router procedure exactly, resolving the report paths from the plan's `reports_dir` (step 2) instead of a fixed default:

1. Read only the `current_milestone` from `.claude/vader/plan.local.md` frontmatter and the current `## Milestone N` section.
2. For each milestone: spawn a fresh Executor Agent (persona at `${CLAUDE_PLUGIN_ROOT}/agents/executor.md`, report to `<reports_dir>/milestone-N-executor.md`, returns only `done|needs-fix`), then a fresh Verifier Agent (persona at `${CLAUDE_PLUGIN_ROOT}/agents/verifier.md`, report to `<reports_dir>/milestone-N-verifier.md`, appends to `<reports_dir>/invariants.md`, returns only `approve|needs-fix`).
3. Fix loop (max 3 cycles), commit, persist branch/PR anchor to the executor report, update `current_milestone` atomically, run the inter-milestone verification gate.
4. After the LAST user milestone, run the **Final Integration pass** in a fresh Verifier: full test/typecheck/sanity, `is_final: true`, reading `<reports_dir>/invariants.md` + all verifier reports as the cross-milestone oracle.
5. Only after Final Integration approves: update status to `done` and output `<promise>Hurra Vader has Triumphed</promise>`
