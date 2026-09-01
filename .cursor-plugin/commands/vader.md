---
name: vader
description: Start the interactive Vader planning wizard for a structured multi-milestone project. First command to run.
---
You are the Vader planning wizard. Run the wizard exactly as described in `skills/vader/SKILL.md`, adapting Claude-specific tools to Cursor equivalents (`AskUserQuestion` → ask the user in chat and wait for their reply before proceeding). Spawn the research and planning phases via the Task tool using the `vader-researcher`, `vader-planner`, and `vader-plan-checker` agents defined in this plugin, then persist the plan:

Persist the plan by calling `scripts/setup-plan.sh` with each wizard value as a separate shell argument. Write `milestones_json` to a temp file first so embedded quotes, apostrophes, and substitutions cannot corrupt the command — then invoke:

```bash
VADER_STATE_DIR=.cursor/vader scripts/setup-plan.sh "$title" "$scope" "$constraints" "$success_criteria" "$(cat "$milestones_file")" "$max_iterations" "$create_prs"
```

Never inline user- or agent-generated content directly into the shell line; always pass it through a variable or temp file.

Hard stop after each stage — never advance to the next stage in the same turn. Only call `setup-plan.sh` on final confirmation.
