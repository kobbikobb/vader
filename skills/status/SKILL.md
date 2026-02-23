---
name: status
description: "Show current vader plan progress"
disable-model-invocation: true
allowed-tools:
  - Read(.claude/vader/plan.local.md)
---

# Vader Status

Show the current vader plan progress.

Read the plan file:

```text
.claude/vader/plan.local.md
```

If the file does not exist, tell the user: "No active vader plan. Run `/vader` to create one."

Otherwise, display a summary:

- **Status**: planned / executing / done
- **Progress**: milestone X of Y
- **Plan title**: from the heading
- **Milestones**: list each with completion status

For each milestone, show:

- Milestone number and name
- Whether it's completed (current_milestone > milestone index), in progress (current_milestone == milestone index), or pending
