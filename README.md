# Vader

A strict, opinionated wizard-driven workflow that wraps [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) to plan and execute multi-milestone software projects with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) plugin

## Installation

```bash
claude plugin add kobbikobb/vader
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
- **Config** - Set iteration limits
- **Save** - Persist the plan

### 2. Execute

```text
/vader:exec
```

Launches a ralph-wiggum loop that works through milestones sequentially. Each milestone is committed separately with the message format: `vader: milestone N - [name]`

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
| `/vader:exec`          | Execute the plan via ralph-wiggum  |
| `/vader:status`        | Show progress                      |
| `/vader:cancel`        | Abort execution                    |
| `/vader:help`          | Usage guide                        |

## How It Works

Vader uses a single ralph-wiggum loop to execute all milestones. The loop prompt instructs Claude to:

1. Check the current milestone in the state file
2. Implement the milestone (code + tests)
3. Verify quality with a review subagent
4. Commit the milestone
5. Update the state file
6. Move to the next milestone
7. Signal completion when all milestones are done

State is stored in `.claude/vader/plan.local.md` (gitignored, ephemeral session state).

## Tips

- Use `--dangerously-skip-permissions` for uninterrupted execution
- Keep milestones small and verifiable
- Each milestone should have clear success criteria

## License

MIT
