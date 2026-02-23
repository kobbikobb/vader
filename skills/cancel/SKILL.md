---
name: cancel
description: "Abort the current vader execution"
disable-model-invocation: true
allowed-tools:
  - Bash(rm -f .claude/vader/plan.local.md .claude/ralph-loop.local.md)
---

# Vader Cancel

Abort the current vader execution and clean up state files.

Run:

```!
rm -f .claude/vader/plan.local.md .claude/ralph-loop.local.md
```

Confirm to the user:

- Vader plan has been removed
- Ralph-wiggum loop has been stopped
- The session will exit normally on next stop

Any code already committed to git is preserved. Only the plan state is removed.
