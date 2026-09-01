---
name: vader-help
description: Show the Vader usage guide.
---
Display the following usage guide:

---

## Vader - Structured Project Execution

Vader is an opinionated wizard-driven workflow that plans and executes multi-milestone software projects using specialized agents.

### Commands

| Command             | Description                                   |
| ------------------- | --------------------------------------------- |
| `/vader [desc]`     | Start the planning wizard                     |
| `/vader-exec`       | Execute the current plan                      |
| `/vader-refine`     | Walk the current branch's diff topic by topic |
| `/vader-status`     | Show plan progress                            |
| `/vader-cancel`     | Abort execution and clean up                  |
| `/vader-help`       | Show this guide                               |

### Workflow

1. **Plan**: Run `/vader` to start the wizard — Researcher explores, Planner drafts milestones, you confirm.
2. **Execute**: Run `/vader-exec` — per milestone a fresh Executor implements and a Verifier validates before advancing.
3. **Refine**: Run `/vader-refine` on a feature branch — Chunker groups the diff into topics; per topic: approve, discuss, edit, defer, or skip.
4. **Monitor**: Run `/vader-status` to check progress across worktrees.
5. **Cancel**: Run `/vader-cancel` to abort if needed.

### Agents

| Agent            | Phase      | Role                                          |
| ---------------- | ---------- | --------------------------------------------- |
| Researcher       | Planning   | Explores codebase, surfaces risks             |
| Planner          | Planning   | Drafts implementation plan with dependencies  |
| Executor         | Execution  | Implements milestone, writes tests            |
| Verifier         | Execution  | Validates milestone goal achieved             |
| Chunker          | Refinement | Groups diff into concept-level topics         |
| Discusser        | Refinement | Answers questions about a topic (read-only)   |
| Editor           | Refinement | Applies scoped refinements within a topic     |
| Refine Verifier  | Refinement | Checks edit stayed in scope, no regressions   |
