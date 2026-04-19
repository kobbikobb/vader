---
name: status
description: "Show vader sessions across all worktrees in the current repo"
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scan-worktrees.sh:*)
  - Read
---

# Vader Status

Show every in-flight vader session across all worktrees of the current repo.

Run the scan:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/scan-worktrees.sh"
```

Output is TSV: `kind<TAB>worktree_path<TAB>branch<TAB>status<TAB>progress<TAB>marker`.
`marker` is `*` for the current worktree, empty otherwise.

If output is empty, tell the user: "No active vader sessions. Run `/vader` to plan, or `/vader:refine` to refine a branch."

Otherwise, render a short table grouped by kind (plan, refine). For each row show: branch, status, progress, worktree path (relative to the current worktree if sensible), and flag the current worktree with `*`.

Tell the user they can `cd` into another worktree and run `/vader:status` or `/vader:refine` there to resume.
