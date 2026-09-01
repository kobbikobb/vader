---
name: vader-cancel
description: Abort the current Vader execution and clean up state files.
---
1. Remove Vader state — run `rm -f .cursor/vader/plan.local.md .cursor/vader/refine.local.md`.
2. Confirm to the user:
   - Vader plan has been removed
   - Any code already committed to git is preserved — only the plan state is removed.
