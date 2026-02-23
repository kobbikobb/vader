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

Vader is an opinionated wizard-driven workflow that wraps ralph-wiggum to plan and execute multi-milestone software projects.

### Commands

| Command                | Description                                    |
| ---------------------- | ---------------------------------------------- |
| `/vader [description]` | Start the planning wizard                      |
| `/vader:exec`          | Execute the current plan via ralph-wiggum      |
| `/vader:status`        | Show plan progress                             |
| `/vader:cancel`        | Abort execution and clean up                   |
| `/vader:help`          | Show this guide                                |

### Workflow

1. **Plan**: Run `/vader` to start the interactive wizard
   - Describe your project
   - Review and refine the plan
   - Split into milestones
   - Configure iteration limits
2. **Execute**: Run `/vader:exec` to start execution
   - Vader composes a prompt and launches a ralph-wiggum loop
   - Claude works through milestones sequentially
   - Each milestone is committed separately
3. **Monitor**: Run `/vader:status` to check progress
4. **Cancel**: Run `/vader:cancel` to abort if needed

### Requirements

- **ralph-wiggum** plugin must be installed
- Best with `--dangerously-skip-permissions` for uninterrupted execution

### State

Plan state is stored in `.claude/vader/plan.local.md` (gitignored, ephemeral session state).
