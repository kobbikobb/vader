# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Vader is a Claude Code plugin that wraps [ralph-wiggum](https://github.com/anthropics/claude-code-plugins/tree/main/ralph-wiggum) to plan and execute multi-milestone software projects via a wizard-driven workflow using specialized agents. It's pure Bash + Markdown + JSON with zero build dependencies.

## Commands

```bash
# Lint
shellcheck scripts/*.sh hooks/*.sh

# Test (requires bats)
bats tests/                    # all tests
bats tests/test-setup-plan.bats  # single test file

# Markdown lint
npx markdownlint-cli2 "**/*.md"

# Local plugin testing
claude --plugin-dir .
```

## Architecture

**Plugin entry point**: `.claude-plugin/plugin.json` defines the plugin metadata.

**Skills** (`skills/*/SKILL.md`): Each slash command (`/vader`, `/vader:exec`, `/vader:refine`, `/vader:status`, `/vader:cancel`, `/vader:help`) is a SKILL.md with YAML frontmatter declaring allowed tools.

**Agents** (`agents/*.md`): Specialized agent personas used during planning, execution, and refinement:

- `researcher.md` — explores codebase, finds patterns, surfaces risks (planning)
- `planner.md` — breaks project into dependency-ordered milestones (planning)
- `executor.md` — implements milestone code and tests (execution)
- `verifier.md` — validates milestone goal was achieved (execution)
- `chunker.md` — groups a diff into concept-level topics (refinement)
- `discusser.md` — answers questions about a topic, read-only (refinement)
- `editor.md` — applies scoped refinements within a topic (refinement)
- `refine-verifier.md` — checks an edit stayed in scope, no regressions (refinement)

During planning, the wizard spawns Researcher and Planner as Task subagents. During execution, `setup-exec.sh` inlines the Executor and Verifier personas into the ralph-wiggum prompt so the loop can spawn them as Agent subagents per milestone. During refinement, `/vader:refine` reads each refine persona and spawns it via Task per topic.

**Scripts** (`scripts/`): Bash scripts called by skills:

- `setup-plan.sh` — writes the plan state file from wizard output (title, scope, constraints, milestones JSON, max_iterations)
- `setup-exec.sh` — reads plan state file, inlines agent personas, and composes a single ralph-wiggum prompt covering all milestones
- `setup-refine.sh` — resolves branch/base/PR, enforces clean tree + non-default branch, writes the refine state file (resumable per-branch)
- `check-permissions.sh` — detects permission mode, nudges toward `--dangerously-skip-permissions`

**Hooks** (`hooks/`): `session-start.sh` fires on SessionStart to warn if not in bypass-permissions mode.

**State files**:

- `.claude/vader/plan.local.md` — plan state (session_id, status, current_milestone, total_milestones, max_iterations, create_prs) + scope/constraints/milestones body
- `.claude/vader/refine.local.md` — refine state keyed on branch (branch, base, base_sha, head_sha, pr_number, topic counts) + topic checklist body

Both are gitignored and ephemeral.

**Key design constraint**: Ralph-wiggum's Stop hook exits the session, so per-milestone chaining is impossible. Instead, `/vader:exec` launches a **single** ralph-wiggum loop covering ALL milestones, with the prompt instructing Claude to work through them sequentially using Executor and Verifier agents.

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core). Each script has a corresponding `tests/test-*.bats` file. Tests create temp directories in `setup()` and clean up in `teardown()`.

## CI

GitHub Actions (`.github/workflows/ci.yml`): ShellCheck, BATS, markdownlint-cli2. Runs on push/PR to main.

## Commits

- No trailers. No `Co-Authored-By`, no `Generated with`, no footers. Just the commit message.
- Keep commit messages short — subject line only unless the "why" isn't obvious.

## Markdownlint

Config in `.markdownlint-cli2.jsonc`: MD013 (line length), MD033 (inline HTML), MD041 (first line heading) are disabled. `PLAN.md` is ignored.
