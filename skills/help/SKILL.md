---
name: help
description: "Show vader usage guide"
disable-model-invocation: true
allowed-tools: []
---

# Vader Help

Display the following usage guide:

---

## Vader - Structured Project Execution

Vader is an opinionated wizard-driven workflow that wraps ralph-wiggum to plan and execute multi-milestone software projects using specialized agents.

### Commands

| Command                | Description                                    |
| ---------------------- | ---------------------------------------------- |
| `/vader [description]` | Start the planning wizard                      |
| `/vader:exec`          | Execute the current plan via ralph-wiggum      |
| `/vader:refine`        | Walk the current branch's diff topic by topic  |
| `/vader:status`        | Show plan progress                             |
| `/vader:cancel`        | Abort execution and clean up                   |
| `/vader:help`          | Show this guide                                |

### Workflow

1. **Plan**: Run `/vader` to start the interactive wizard
   - A **Researcher** agent explores the codebase and surfaces risks
   - A **Planner** agent drafts the implementation plan
   - You review, refine, split into milestones, and confirm
   - Configure iteration limits and PR creation
2. **Execute**: Run `/vader:exec` to start execution
   - For each milestone, an **Executor** agent implements the changes
   - A **Verifier** agent validates the work before committing
   - Lint, format, typecheck, and tests run before each commit
   - Each milestone gets its own branch and PR (if enabled)
3. **Refine**: Run `/vader:refine` on a feature branch to walk the diff
   - A **Chunker** agent groups the diff into concept-level topics
   - For each topic: approve, discuss (**Discusser**), edit (**Editor** + **Refine Verifier**), defer, jump, back, or skip
   - Edits commit per topic; if a PR exists, the loop ends with a `git push` (never force)
4. **Monitor**: Run `/vader:status` to check progress
5. **Cancel**: Run `/vader:cancel` to abort if needed

### Agents

| Agent           | Phase      | Role                                           |
| --------------- | ---------- | ---------------------------------------------- |
| Researcher      | Planning   | Explores codebase, surfaces risks              |
| Planner         | Planning   | Drafts implementation plan with dependencies   |
| Executor        | Execution  | Implements milestone, writes tests             |
| Verifier        | Execution  | Validates milestone goal achieved              |
| Chunker         | Refinement | Groups diff into concept-level topics          |
| Discusser       | Refinement | Answers questions about a topic (read-only)    |
| Editor          | Refinement | Applies scoped refinements within a topic      |
| Refine Verifier | Refinement | Checks edit stayed in scope, no regressions    |

Agent personas are defined in `agents/*.md` and can be customized.

### Requirements

- **ralph-wiggum** plugin (optional — vader falls back to direct execution)
- Best with `--dangerously-skip-permissions` for uninterrupted execution

### State

Plan state is stored in `.claude/vader/plan.local.md`. Refine state is stored in `.claude/vader/refine.local.md` keyed by branch so re-invocation resumes. Both are gitignored, ephemeral session state.
