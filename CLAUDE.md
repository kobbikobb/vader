# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Vader is a Claude Code plugin that plans and executes multi-milestone software projects via a wizard-driven workflow using specialized agents. It's pure Bash + Markdown + JSON with zero build dependencies.

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

During planning, the wizard spawns Researcher and Planner as Task subagents. During execution, `setup-exec.sh` composes the thin-router prompt: it references the Executor/Verifier personas by path and routes subagent reports to files, so the supervisor holds only the current milestone index and latest verdict (details below under "State files"). During refinement, `/vader:refine` reads each refine persona and spawns it via Task per topic.

**Scripts** (`scripts/`): Bash scripts called by skills:

- `setup-plan.sh` — writes the plan state file from wizard output (title, scope, constraints, milestones JSON, max_iterations)
- `setup-exec.sh` — reads plan state file, references executor/verifier personas by path, and composes a single thin-router prompt covering all milestones
- `setup-refine.sh` — resolves branch/base/PR, enforces clean tree + non-default branch, writes the refine state file (resumable per-branch)
- `check-permissions.sh` — detects permission mode, nudges toward `--dangerously-skip-permissions`

**Hooks** (`hooks/`): `session-start.sh` fires on SessionStart to warn if not in bypass-permissions mode. `pre-tool-use.sh` fires on PreToolUse for the file-editing tools and denies them while the plan state file says `status: planned` — the window between `/vader` saving a plan and `/vader:exec` starting it. Hooks still run under `--dangerously-skip-permissions`, which is why the gate lives here and not in skill `allowed-tools`.

**State files**:

- `.claude/vader/plan.local.md` — plan state (session_id, status, current_milestone, total_milestones, max_iterations, create_prs, reports_dir) + scope/constraints/milestones body
- `.claude/vader/reports/` — per-milestone executor/verifier reports (`milestone-N-*.md`) + `invariants.md` (the cross-milestone oracle for Final Integration). Durable memory so the supervisor can be `/clear`ed mid-epic without losing progress.
- `.claude/vader/refine.local.md` — refine state keyed on branch (branch, base, base_sha, head_sha, pr_number, topic counts) + topic checklist body

Both are gitignored and ephemeral.

**Key design constraint**: `/vader:exec` launches a **single** thin-router execution prompt covering ALL milestones. To stop that loop from degrading late milestones, the prompt is a **thin router**: each milestone runs in a fresh Executor/Verifier subagent that reads its scope from disk and writes reports to `.claude/vader/reports/`, returning only a one-word verdict. The supervisor never accumulates plan bodies, personas, diffs, or test output, so context stays lean enough to stay hands-off across the whole epic.

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core). Each script has a corresponding `tests/test-*.bats` file. Tests create temp directories in `setup()` and clean up in `teardown()`.

## CI

GitHub Actions (`.github/workflows/ci.yml`): ShellCheck, BATS, markdownlint-cli2. Runs on push/PR to main.

## Commits

- No trailers. No `Co-Authored-By`, no `Generated with`, no footers. Just the commit message.
- Keep commit messages short — subject line only unless the "why" isn't obvious.

## Markdownlint

Config in `.markdownlint-cli2.jsonc`: MD013 (line length), MD033 (inline HTML), MD041 (first line heading) are disabled. `PLAN.md` is ignored.
