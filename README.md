# Vader

A strict, opinionated wizard-driven workflow that wraps [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) to plan and execute multi-milestone software projects with [Claude Code](https://docs.anthropic.com/en/docs/claude-code), using specialized agents for each phase of work.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) plugin (optional — vader falls back to direct execution if not installed)

## Installation

```text
/plugin install vader@kobbikobb/vader
```

First-time setup requires adding the marketplace:

```text
/plugin marketplace add kobbikobb/vader
/plugin install vader@vader
```

## Usage

### 1. Plan

```text
/vader Build a REST API with authentication
```

The planning wizard guides you through:

- **Scope** - A Researcher agent explores the codebase and surfaces risks
- **Plan** - A Planner agent drafts the implementation with dependencies
- **Milestones** - Split into verifiable milestones (you review and refine)
- **Config** - Set iteration limits, enable/disable PR creation per milestone
- **Save** - Persist the plan

### 2. Execute

```text
/vader:exec
```

Launches a loop that works through milestones sequentially. For each milestone:

1. An **Executor** agent implements the changes and writes tests
2. A **Verifier** agent validates the work (goal met, tests pass, no regressions)
3. If the Verifier finds issues, the Executor fixes them (up to 3 cycles)
4. Milestone is committed with message: `vader: milestone N - [name]`

When PR creation is enabled (default), each milestone gets its own branch and PR.

### 3. Monitor

```text
/vader:status
```

### 4. Cancel

```text
/vader:cancel
```

## Commands

| Command                | Description                        |
| ---------------------- | ---------------------------------- |
| `/vader [description]` | Start the planning wizard          |
| `/vader:exec`          | Execute the plan                   |
| `/vader:status`        | Show progress                      |
| `/vader:cancel`        | Abort execution                    |
| `/vader:help`          | Usage guide                        |

## Agents

Vader uses four specialized agents defined in `agents/*.md`:

| Agent      | Phase     | Responsibility                                        |
| ---------- | --------- | ----------------------------------------------------- |
| Researcher | Planning  | Explores codebase, finds patterns, surfaces risks     |
| Planner    | Planning  | Breaks project into dependency-ordered milestones     |
| Executor   | Execution | Implements milestone, writes tests, runs them         |
| Verifier   | Execution | Validates goal achieved, checks quality and security  |

Agent personas are customizable — edit the markdown files in `agents/` to match your team's conventions and standards.

## How It Works

**Planning phase** (`/vader`): The wizard spawns a Researcher agent to explore the codebase, then a Planner agent to draft the implementation plan. You review and refine through interactive stages.

**Execution phase** (`/vader:exec`): A loop works through milestones. For each milestone, it spawns an Executor agent to implement and a Verifier agent to validate. The Verifier checks that the milestone goal was actually achieved — not just that code was written. If verification fails, the Executor gets another attempt (up to 3 cycles). When PR creation is enabled, each milestone gets its own branch and PR.

State is stored in `.claude/vader/plan.local.md` (gitignored, ephemeral session state).

## Execution Modes

- **ralph-wiggum mode** (default): If the ralph-loop plugin is installed, vader delegates to it for iteration management
- **Direct mode** (fallback): If ralph-loop is not available, vader executes the plan inline in the current session

## Tips

- Use `--dangerously-skip-permissions` for uninterrupted execution
- Keep milestones small and verifiable
- Each milestone should have clear success criteria
- Customize agent personas in `agents/*.md` to match your team's conventions
- If execution is interrupted mid-milestone, run `/vader:status` to check progress, then `/vader:exec` to resume from where it left off

## License

MIT
