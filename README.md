<p align="center">
  <img src="vader-icon.svg" width="128" height="128" alt="Vader">
</p>

<h1 align="center">Vader</h1>

Plan it. Break it into milestones. Build it. Verify it. Ship it.

<p align="center">
  <img src="vader-demo.svg" width="800" alt="Vader demo">
</p>

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for structured, multi-milestone software projects. No framework bloat — just a wizard, four agents, and a loop.

## Why Vader

Most AI coding tools are either too simple (one-shot prompts) or too complex (30 commands, 20 agents, 7 modes). Vader sits in between:

- **You plan together** — a wizard walks you through scope, milestones, and success criteria
- **It builds autonomously** — an Executor agent implements each milestone while a Verifier validates it actually works
- **State survives crashes** — progress is tracked in a file, not conversation memory

## Quick Start

```text
/plugin marketplace add kobbikobb/vader
/plugin install vader@vader
```

Then:

```text
/vader Add user authentication with JWT tokens
```

The wizard guides you through 5 stages, then:

```text
/vader:exec
```

Walk away. Come back to committed, verified code.

## How It Works

```text
/vader "description"          /vader:exec
        │                           │
   ┌────▼────┐                ┌─────▼─────┐
   │Research │                │ For each  │
   │codebase │                │ milestone:│
   └────┬────┘                │           │
   ┌────▼────┐                │ Executor  │──▶ implement + test
   │  Draft  │                │     │     │
   │  plan   │                │ Verifier  │──▶ validate goal met
   └────┬────┘                │     │     │
   ┌────▼────┐                │  Pass? ───│──▶ commit + next
   │  Split  │                │  Fail? ───│──▶ fix (up to 3x)
   │mileston.│                └───────────┘
   └────┬────┘
   ┌────▼────┐
   │  Save   │
   │  plan   │
   └─────────┘
```

## Commands

| Command | What it does |
|---|---|
| `/vader [description]` | Plan a project — interactive wizard |
| `/vader:exec` | Execute the plan autonomously |
| `/vader:status` | Check progress |
| `/vader:cancel` | Abort and clean up |
| `/vader:help` | Usage guide |

## Agents

Four specialized agents, each a markdown file you can customize:

| Agent | Phase | Job |
|---|---|---|
| **Researcher** | Planning | Explores codebase, finds patterns, surfaces risks |
| **Planner** | Planning | Breaks project into dependency-ordered milestones |
| **Executor** | Execution | Implements code and tests for one milestone |
| **Verifier** | Execution | Validates the milestone goal was actually achieved |

Edit `agents/*.md` to match your team's conventions.

## Execution Modes

- **ralph-wiggum mode** (default) — delegates to the [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) plugin for iteration management
- **Direct mode** (fallback) — executes inline if ralph-wiggum isn't installed

## Tips

- Use `--dangerously-skip-permissions` for uninterrupted overnight execution
- Keep milestones small and verifiable — each should have clear success criteria
- Interrupted mid-build? Run `/vader:status` then `/vader:exec` to resume
- Customize agent personas in `agents/` to encode your project's rules

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) plugin (optional)

## License

MIT
