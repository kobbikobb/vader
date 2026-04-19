---
name: status
description: "Show vader sessions across all worktrees in the current repo"
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scan-worktrees.sh:*)
  - Read(.claude/vader/plan.local.md)
  - Read(.claude/vader/refine.local.md)
---

# Vader Status

Show every in-flight vader session across all worktrees of the current repo, plus milestone detail for the current worktree's plan.

Run the scan:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/scan-worktrees.sh"
```

Output is TSV: `kind<TAB>worktree_path<TAB>branch<TAB>status<TAB>progress<TAB>marker`.
`marker` is `*` for the current worktree, empty otherwise.

If output is empty, tell the user: "No active vader sessions. Run `/vader` to plan, or `/vader:refine` to refine a branch." Stop.

Otherwise:

1. Render a short table grouped by kind (plan, refine). For each row show branch, status, progress, worktree path (relative if short), and flag the current worktree with `*`.
2. If a `plan` row is marked `*`, also read `.claude/vader/plan.local.md` and append a milestone breakdown: for each milestone list number, name, and whether it is completed (`current_milestone > index`), in progress (`current_milestone == index`), or pending.
3. If a `refine` row is marked `*`, also read `.claude/vader/refine.local.md` and append the topic checklist from the `## Topics` section so the user can see what's resolved, deferred, or pending in this worktree.
4. Tell the user they can `cd` into another worktree and run `/vader:status` there to see its detail, or run `/vader:refine` there to resume refinement.
