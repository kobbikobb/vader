---
name: vader-status
description: Show Vader plan and refine sessions across all worktrees in the current repo.
---
1. Run the worktree scan:

   ```bash
   VADER_STATE_DIR=.cursor/vader scripts/scan-worktrees.sh
   ```

2. Output is TSV: `kind<TAB>worktree_path<TAB>branch<TAB>status<TAB>progress<TAB>marker` (`*` = current worktree).
3. If empty: tell the user "No active vader sessions. Run `/vader` to plan, or `/vader:refine` to refine a branch." Stop.
4. Otherwise render a table grouped by kind (plan, refine).
   - For a `plan` row marked `*`: read `.cursor/vader/plan.local.md` and append a milestone breakdown (completed / in progress / pending).
   - For a `refine` row marked `*`: read `.cursor/vader/refine.local.md` and append the topic checklist from the `## Topics` section.
5. Tell the user they can `cd` into another worktree and run `/vader:status` there for detail, or `/vader:refine` there to resume.
