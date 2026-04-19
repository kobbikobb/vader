<p align="center">
  <img src="vader-banner.svg" width="800" alt="Vader">
</p>

<p align="center">
  <img src="vader-demo.svg" width="800" alt="Vader demo">
</p>

No framework bloat — just a wizard, a handful of agents, and a loop.

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

Got an existing feature branch you want to review concept by concept?

```text
/vader:refine
```

A Chunker groups the diff into topics. For each one: approve, discuss, edit, defer, jump, back, or skip. Edits go through an Editor and a Refine Verifier before a per-topic commit. Pushes to the PR at the end if one exists — never force.

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
| --- | --- |
| `/vader [description]` | Plan a project — interactive wizard |
| `/vader:exec` | Execute the plan autonomously |
| `/vader:refine` | Walk the current branch's diff topic by topic |
| `/vader:status` | Check progress |
| `/vader:cancel` | Abort and clean up |
| `/vader:help` | Usage guide |

## Agents

Specialized agents, each a markdown file you can customize:

| Agent | Phase | Job |
| --- | --- | --- |
| **Researcher** | Planning | Explores codebase, finds patterns, surfaces risks |
| **Planner** | Planning | Breaks project into dependency-ordered milestones |
| **Executor** | Execution | Implements code and tests for one milestone |
| **Verifier** | Execution | Validates the milestone goal was actually achieved |
| **Chunker** | Refinement | Groups a diff into concept-level topics |
| **Discusser** | Refinement | Answers questions about a topic (read-only) |
| **Editor** | Refinement | Applies refinements within a topic's file scope |
| **Refine Verifier** | Refinement | Checks an edit stayed in scope, no regressions |

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
