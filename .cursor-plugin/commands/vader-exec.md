---
name: vader-exec
description: Execute the current Vader plan milestone by milestone via fresh executor/verifier subagents.
---
Execute the current Vader plan using **direct execution mode** (Cursor has no ralph-wiggum loop — never try to invoke it).

1. Read `VADER_STATE_DIR` default `.cursor/vader` — if `.cursor/vader/plan.local.md` does not exist, tell the user to run `/vader` first and stop.
2. Note the `reports_dir` from the plan frontmatter and use it for every report path.
3. Compose the prompt by running `VADER_STATE_DIR=.cursor/vader scripts/setup-exec.sh`. The output is the thin-router prompt text. Follow its procedure inline:

   - Read only `current_milestone` from the plan frontmatter and the current `## Milestone N` section.
   - Per milestone: spawn a fresh Task agent from `vader-executor` (report to `<reports_dir>/milestone-N-executor.md`, returns `done|needs-fix`), then a fresh Task agent from `vader-verifier` (report to `<reports_dir>/milestone-N-verifier.md`, appends to `<reports_dir>/invariants.md`, returns `approve|needs-fix`).
   - Fix loop (max 3 cycles), commit, update `current_milestone`, run the inter-milestone verification gate.
   - After the last milestone, run a **Final Integration pass** in a fresh `vader-verifier` reading `<reports_dir>/invariants.md` + all verifier reports.
   - Only after Final Integration approves: set status `done` and output `<promise>Hurra Vader has Triumphed</promise>`. Keep the true-supervisor invariant: hold only milestone index + latest verdict; heavy content stays on disk in reports.
