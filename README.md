# Vader

A strict, opinionated wizard-driven workflow that wraps [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) to plan and execute multi-milestone software projects with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

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

- **Scope** - Describe your project, Claude explores the codebase
- **Plan** - Review files to add/change
- **Milestones** - Split into verifiable milestones
- **Config** - Set iteration limits, enable/disable PR creation per milestone
- **Save** - Persist the plan

### 2. Execute

```text
/vader:exec
```

Launches a loop that works through milestones sequentially. Each milestone is committed separately with the message format: `vader: milestone N - [name]`

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

## How It Works

Vader executes all milestones in a single loop. For each milestone:

1. Check the current milestone in the state file
2. Create a branch (if PR creation is enabled)
3. Implement the milestone (code + tests)
4. Run lint, format, and typecheck to verify code quality
5. Run tests
6. Review the diff for obvious issues
7. Commit and push
8. Update the state file and move to the next milestone
9. Create PRs after all milestones are complete (if enabled)

State is stored in `.claude/vader/plan.local.md` (gitignored, ephemeral session state).

## Execution Modes

- **ralph-wiggum mode** (default): If the ralph-loop plugin is installed, vader delegates to it for iteration management
- **Direct mode** (fallback): If ralph-loop is not available, vader executes the plan inline in the current session

## Tips

- Use `--dangerously-skip-permissions` for uninterrupted execution
- Keep milestones small and verifiable
- Each milestone should have clear success criteria
- If execution is interrupted mid-milestone, run `/vader:status` to check progress, then `/vader:exec` to resume from where it left off

## License

MIT
