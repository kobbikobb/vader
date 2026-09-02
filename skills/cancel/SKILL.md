---
name: cancel
description: "Abort the current vader execution"
disable-model-invocation: true
allowed-tools:
  - Bash(rm -f "${VADER_STATE_DIR:-.claude/vader}/plan.local.md")
---

# Vader Cancel

Abort the current vader execution and clean up state files.

Run:

```!
rm -f "${VADER_STATE_DIR:-.claude/vader}/plan.local.md"
```

Confirm to the user:

- Vader plan has been removed
- Execution loop state has been removed
- The session will exit normally on next stop

Any code already committed to git is preserved. Only the plan state is removed.
