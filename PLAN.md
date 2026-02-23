# Vader Plugin - Implementation Plan

## Context
Build an open-source Claude Code plugin called **vader** - a strict, opinionated wizard-driven workflow that wraps ralph-wiggum to plan and execute multi-milestone software projects. Repo: https://github.com/kobbikobb/vader

## Out of Scope
- GitHub repo creation (already exists at kobbikobb/vader)
- Marketplace listing (manual)
- Git setup (manual, done before execution)

## Key Design Insight
Ralph-wiggum's Stop hook **exits the session** when the completion promise is detected. Per-milestone chaining is impossible. Instead: `/vader:exec` launches a **single ralph-wiggum loop** covering ALL milestones. The prompt instructs Claude to work through milestones sequentially, updating the state file as it goes.

## Plugin Structure
```
vader/
  .claude-plugin/plugin.json
  skills/
    vader/SKILL.md            # /vader - Planning wizard
    exec/SKILL.md             # /vader:exec - Execute plan via ralph-wiggum
    cancel/SKILL.md           # /vader:cancel - Abort execution
    status/SKILL.md           # /vader:status - Show plan progress
    help/SKILL.md             # /vader:help - Usage guide
  hooks/
    hooks.json                # SessionStart hook
    session-start.sh          # Permissions nudge
  scripts/
    setup-plan.sh             # Write plan state file
    setup-exec.sh             # Compose ralph-wiggum prompt from plan
    check-permissions.sh      # Detect permission mode
  tests/
    test-setup-plan.bats
    test-setup-exec.bats
    test-check-permissions.bats
  README.md
  LICENSE                     # MIT
  .github/workflows/
    ci.yml                    # ShellCheck + BATS + markdownlint
    release.yml               # Tag-triggered GitHub release
```

**Language**: Bash + Markdown + JSON (zero dependencies, no build step)

## Core Flow

### 1. `/vader` - Interactive Planning Wizard
Skill at `skills/vader/SKILL.md`. Frontmatter:
```yaml
---
name: vader
description: "Interactive planning wizard for structured software projects"
disable-model-invocation: true
argument-hint: "[project description]"
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-plan.sh:*)
  - Read
  - Grep
  - Glob
  - Task
  - AskUserQuestion
---
```
Body instructs Claude through 5 stages:
1. **Scope** - User describes project. Claude uses Explore agents (Task tool, subagent_type=Explore) to understand codebase. Asks questions until scope, constraints, and success criteria are locked.
2. **Plan** - Draft plan with files to add/change. User approves/revises.
3. **Milestones** - Split into milestones (name, scope, files, success criteria). Refine with user.
4. **Config** - Ask iteration count (default 15).
5. **Save** - Call `setup-plan.sh` to write state file. Tell user to run `/vader:exec`.

### 2. State File `.claude/vader/plan.local.md`
```yaml
---
session_id: "<uuid>"
status: planned | executing | done
current_milestone: 0
total_milestones: 3
max_iterations: 15
created_at: "2026-02-23T..."
---
# Plan: [Title]
## Scope
[description]
## Constraints
- ...
## Success Criteria
- ...
## Milestone 1: [Name]
### Files
- path/file.ts (add|change)
### Success Criteria
- ...
## Milestone 2: [Name]
...
```

### 3. `/vader:exec` - Execute via Ralph-Wiggum
Skill at `skills/exec/SKILL.md`. Frontmatter:
```yaml
---
name: exec
description: "Execute the current vader plan via ralph-wiggum loop"
disable-model-invocation: true
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-exec.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-permissions.sh:*)
  - Read(.claude/vader/plan.local.md)
---
```
Body instructs Claude to:
1. Run `check-permissions.sh` - if not `bypassPermissions`, warn and suggest `--dangerously-skip-permissions`
2. Read `.claude/vader/plan.local.md` - hard-fail if missing
3. Run `setup-exec.sh` which:
   - Reads the plan file
   - Composes a **single prompt** containing ALL milestones with instructions to work through them sequentially
   - Outputs the composed prompt to stdout
4. Instruct Claude to invoke `/ralph-wiggum:ralph-loop` via the Skill tool with: `<composed-prompt> --max-iterations <N> --completion-promise "Hurra Vader has Triumphed"`

The composed prompt instructs Claude to:
- Check `current_milestone` in state file
- Implement that milestone (code + tests)
- Verify quality with a subagent (Task tool, subagent_type=Explore to review)
- Commit: `vader: milestone N - [name]`
- Update `current_milestone` in state file
- Move to next milestone
- When ALL milestones done: output `<promise>Hurra Vader has Triumphed</promise>`

### 4. Permission Nudge `hooks/session-start.sh`
`hooks.json`:
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
      }]
    }]
  }
}
```
Script reads stdin JSON, checks `permission_mode`. If not `"bypassPermissions"`, outputs:
```json
{"systemMessage": "Vader works best with --dangerously-skip-permissions. Restart with: claude --dangerously-skip-permissions"}
```

### 5. `/vader:cancel` - Abort Execution
Skill at `skills/cancel/SKILL.md`. Removes `.claude/vader/plan.local.md` and `.claude/ralph-loop.local.md` (ralph-wiggum's state). Stops both vader and the underlying ralph loop.

### 6. `/vader:status` - Read state file, display progress
### 7. `/vader:help` - Display usage documentation

## Implementation Order (exact file sequence)
1. `.claude-plugin/plugin.json`
2. `LICENSE` (MIT)
3. `scripts/check-permissions.sh` + `chmod +x`
4. `scripts/setup-plan.sh` + `chmod +x`
5. `scripts/setup-exec.sh` + `chmod +x`
6. `hooks/hooks.json`
7. `hooks/session-start.sh` + `chmod +x`
8. `skills/vader/SKILL.md`
9. `skills/exec/SKILL.md`
10. `skills/cancel/SKILL.md`
11. `skills/status/SKILL.md`
12. `skills/help/SKILL.md`
13. `tests/test-setup-plan.bats`
14. `tests/test-setup-exec.bats`
15. `tests/test-check-permissions.bats`
16. `.github/workflows/ci.yml`
17. `.github/workflows/release.yml`
18. `README.md`
19. Create PR to https://github.com/kobbikobb/vader with label `enhancement`

## Reference Files
- Ralph-wiggum setup script: `~/.claude/plugins/cache/claude-code-plugins/ralph-wiggum/1.0.0/scripts/setup-ralph-loop.sh`
- Ralph-wiggum stop hook: `~/.claude/plugins/cache/claude-code-plugins/ralph-wiggum/1.0.0/hooks/stop-hook.sh`
- Ralph-wiggum command: `~/.claude/plugins/cache/claude-code-plugins/ralph-wiggum/1.0.0/commands/ralph-loop.md`
- Ralph-wiggum hooks.json: `~/.claude/plugins/cache/claude-code-plugins/ralph-wiggum/1.0.0/hooks/hooks.json`
- Ralph-wiggum plugin.json: `~/.claude/plugins/cache/claude-code-plugins/ralph-wiggum/1.0.0/.claude-plugin/plugin.json`

## Verification
1. `shellcheck scripts/*.sh hooks/*.sh`
2. Run BATS test suite
3. `claude --plugin-dir .` to test locally
4. Test `/vader` wizard flow end-to-end
5. Test `/vader:exec` invokes ralph-wiggum correctly
6. Verify SessionStart hook nudges on permissions

## Decisions
- **Single loop**: One ralph-wiggum loop for all milestones (NOT per-milestone)
- **Plugin name**: `vader`
- **Dependency**: Hard-fail if ralph-wiggum not installed
- **State**: `.local.md` (gitignored) - plans are ephemeral session state
- **PR target**: https://github.com/kobbikobb/vader

## Resolved Questions
1. **Skill invocation**: The SKILL.md will instruct Claude to use the Skill tool directly to invoke `ralph-wiggum:ralph-loop`. Claude always has access to the Skill tool — no special `allowed-tools` entry needed.
2. **Cancel skill**: Yes — `/vader:cancel` is included in the plan (item 10, `skills/cancel/SKILL.md`). It removes both `.claude/vader/plan.local.md` and `.claude/ralph-loop.local.md`.
