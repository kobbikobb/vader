---
name: refine
description: "Interactive concept-level refinement of the current branch's changes"
disable-model-invocation: true
argument-hint: ""
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-refine.sh:*)
  - Bash(git:*)
  - Bash(gh:*)
  - Read
  - Edit
  - Write
  - Task
  - AskUserQuestion
---

# Vader Refine

You are the Vader refinement guide. Walk the user through the current branch's diff one **topic** at a time — concept-level, not line-level. For each topic: discuss, edit if asked, then commit.

**RULE**: You MUST use `AskUserQuestion` and wait for the user's response before advancing to the next stage or committing any change. Never proceed to the next stage in the same turn.

## Stage 1: Setup

Run the setup script:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-refine.sh"
```

If it exits non-zero, stop and show the error.

Parse stdout for: `branch`, `base`, `pr_number`, `changed_lines`, `large_diff`, `resuming`, `state_file`.

Read `.claude/vader/refine.local.md` for full session state.

## Stage 2: Large-Diff Guard

If `large_diff` is `true`, warn the user and ask via `AskUserQuestion`:

- **Split into segments** (recommended) — Stage 3 runs in segmented mode: spawn the Chunker once on segment groups (directories or feature clusters), user picks ONE segment, scope the rest of the flow to that segment's paths, remaining segments listed so the user can rerun `/vader:refine` per segment
- **Proceed whole** — continue without splitting; pass directory-level pre-grouping as a hint to chunk mode
- **Abort** — stop

**STOP**: Next action MUST be `AskUserQuestion`. Skip Stage 2 entirely if `large_diff` is `false`.

## Stage 3: Chunk

If `resuming` is `true` and the state file already has topics, skip to Stage 4.

Read the Chunker persona from `${CLAUDE_PLUGIN_ROOT}/agents/chunker.md`.

Spawn a **Chunker** agent via Task with `subagent_type=Explore`:

- Include the persona in the prompt
- Include the diff: `git diff <base_sha>...HEAD` (from state frontmatter)
- In segmented mode, restrict the diff to the chosen segment's paths (`git diff <base_sha>...HEAD -- <paths>`)

Write topics to the state file:

- Update frontmatter: `total_topics: <count>`, `resolved_topics: 0`, `deferred_topics: 0`
- Replace the `## Topics` section with a checklist using status markers:
  - `- [ ] N. <title> — <file list>` for pending
  - `- [x] N. ...` for resolved
  - `- [~] N. ...` for deferred
  - `- [-] N. ...` for skipped
- Append a `## Topic Details` section with the full JSON for later reference

Present the list via `AskUserQuestion`:

- **Start refining** — proceed to Stage 4
- **Edit list** — user supplies free-text changes (rename/merge/split/add/remove/reorder); apply, re-render, ask again
- **Rechunk** — respawn Chunker with user guidance, replace the list, ask again

**STOP**: Do NOT proceed to Stage 4 until the user chooses **Start refining**.

## Stage 4: Refinement Loop

Keep a cursor tracking the current topic. Start at the first pending (`[ ]`) topic.

For the current topic:

1. Present summary + risks.
2. Ask via `AskUserQuestion`:
   - **Approve** — mark `[x]`, advance cursor, no commit
   - **Discuss** — user asks a question (see sub-flow below)
   - **Edit** — user describes a refinement (see sub-flow below)
   - **Defer** — mark `[~]`, advance cursor; the loop revisits deferred topics at the end of the forward pass
   - **Back** — move cursor to the previous topic (any status); re-present it
   - **Jump** — user supplies a topic number (1..total_topics); cursor moves there regardless of status
   - **Skip** — mark `[-]`, advance cursor, do not revisit

After every status change, update the state frontmatter counts (`resolved_topics`, `deferred_topics`) and the checklist.

### Discuss sub-flow

Read `${CLAUDE_PLUGIN_ROOT}/agents/discusser.md`. Spawn a Discusser via Task with `subagent_type=Explore` — persona + topic + user question. Show the answer. Re-open the menu on the same topic.

### Edit sub-flow

1. Read `${CLAUDE_PLUGIN_ROOT}/agents/editor.md`. Spawn an Editor via Task with `subagent_type=general-purpose` — persona + topic + refinement request.
2. After the Editor returns, run `git diff` on the touched files and show it to the user.
3. Read `${CLAUDE_PLUGIN_ROOT}/agents/refine-verifier.md`. Spawn a Refine Verifier via Task with `subagent_type=general-purpose` — persona + topic + list of touched files + the diff. It verifies scope, regressions, quality, and security; returns `approve` or `needs-fix` with specific `file:line` issues.
4. Show the Verifier verdict to the user.
5. Ask via `AskUserQuestion`: **Commit**, **Iterate** (user sends a new refinement request; go back to step 1), or **Discard** (`git restore --staged -- <touched files>` and `git checkout -- <touched files>` — do NOT run `git restore .` or `git clean`; only touch files the Editor modified).
6. On **Commit**: `git add -- <touched files>`, `git commit -m "refine: <topic title>"`, mark the topic `[x]`, **refresh `head_sha` in the state frontmatter** to `git rev-parse HEAD`.

### End of forward pass

When the cursor reaches the last topic and deferred (`[~]`) topics remain, rewind the cursor to the first deferred topic and re-present the menu for each. Loop until no pending or deferred topics remain.

**STOP**: Next action MUST be `AskUserQuestion` before every edit, commit, discard, defer, back, and topic transition.

## Stage 5: Finalize

When every topic is `[x]` or `[-]`:

1. Read `pr_number` from state frontmatter.
2. If a PR number is present, ask via `AskUserQuestion`: **Push + comment**, **Push only**, or **Skip push**.
   - On push: `git push` (no force). If the remote has diverged, abort with a clear message and tell the user to reconcile manually.
   - On **Push + comment**: `gh pr comment <pr_number> --body "<summary of resolved topics>"`
3. If no PR number: print a summary of commits made and tell the user to push when ready.
4. Update state frontmatter: `status: done`.

Report a short summary of what changed and stop.

## Safety Rules

- NEVER force-push.
- NEVER rewrite git history (no amend, rebase, reset).
- NEVER run `git restore .` or `git clean` — only touch files the Editor modified.
- NEVER edit files outside the current topic's scope without asking.
- Each refinement is a NEW commit on top of the branch.
