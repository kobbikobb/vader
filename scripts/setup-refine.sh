#!/bin/bash

# Prepare the vader refine state file for the current branch
# Usage: setup-refine.sh
# Resolves branch/base/PR, verifies preconditions, writes state, prints summary

set -euo pipefail

STATE_DIR=".claude/vader"
STATE_FILE="$STATE_DIR/refine.local.md"
LARGE_DIFF_THRESHOLD="${VADER_LARGE_DIFF_THRESHOLD:-2000}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

BRANCH=$(git branch --show-current)
if [[ -z "$BRANCH" ]]; then
  echo "Error: detached HEAD — check out a branch first" >&2
  exit 1
fi

DEFAULT_BRANCH=""
if git show-ref --verify --quiet refs/remotes/origin/main; then
  DEFAULT_BRANCH="main"
elif git show-ref --verify --quiet refs/remotes/origin/master; then
  DEFAULT_BRANCH="master"
elif git show-ref --verify --quiet refs/heads/main; then
  DEFAULT_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
  DEFAULT_BRANCH="master"
else
  echo "Error: could not detect default branch (main/master)" >&2
  exit 1
fi

if [[ "$BRANCH" == "$DEFAULT_BRANCH" ]]; then
  echo "Error: you are on '$DEFAULT_BRANCH' — switch to a feature branch to refine" >&2
  exit 1
fi

PR_NUMBER=""
PR_BASE=""
if command -v gh >/dev/null 2>&1; then
  PR_JSON=$(gh pr view --json number,baseRefName 2>/dev/null || true)
  if [[ -n "$PR_JSON" ]]; then
    PR_NUMBER=$(echo "$PR_JSON" | jq -r '.number // empty')
    PR_BASE=$(echo "$PR_JSON" | jq -r '.baseRefName // empty')
  fi
fi

BASE="${PR_BASE:-$DEFAULT_BRANCH}"

BASE_REF=""
if git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
  BASE_REF="origin/$BASE"
elif git show-ref --verify --quiet "refs/heads/$BASE"; then
  BASE_REF="$BASE"
else
  echo "Error: base branch '$BASE' not found locally or on origin" >&2
  exit 1
fi

BASE_SHA=$(git merge-base "$BASE_REF" HEAD)
HEAD_SHA=$(git rev-parse HEAD)

if [[ "$BASE_SHA" == "$HEAD_SHA" ]]; then
  echo "Error: no changes on '$BRANCH' vs '$BASE' — nothing to refine" >&2
  exit 1
fi

# Dirty check, excluding our own state dir via pathspec
DIRTY=$(git -c core.quotePath=false status --porcelain -- . ':(exclude).claude/vader')
if [[ -n "$DIRTY" ]]; then
  echo "Error: working tree is dirty. Commit or stash your changes before refining." >&2
  exit 1
fi

SHORTSTAT=$(git diff --shortstat "$BASE_SHA...HEAD" || true)
INSERT=$(echo "$SHORTSTAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || true)
DELETE=$(echo "$SHORTSTAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || true)
INSERT="${INSERT:-0}"
DELETE="${DELETE:-0}"
CHANGED_LINES=$((INSERT + DELETE))

LARGE_DIFF="false"
if [[ "$CHANGED_LINES" -gt "$LARGE_DIFF_THRESHOLD" ]]; then
  LARGE_DIFF="true"
fi

mkdir -p "$STATE_DIR"

get_field() {
  awk -F': *' -v k="$1" '$1 == k {gsub(/^"|"$/, "", $2); print $2; exit}' "$STATE_FILE"
}

RESUMING="false"
if [[ -f "$STATE_FILE" ]]; then
  EXISTING_STATUS=$(get_field "status")
  EXISTING_BASE=$(get_field "base_sha")
  EXISTING_BRANCH=$(get_field "branch")
  if [[ "$EXISTING_BRANCH" == "$BRANCH" && "$EXISTING_BASE" == "$BASE_SHA" && "$EXISTING_STATUS" != "done" ]]; then
    RESUMING="true"
  fi
fi

if [[ "$RESUMING" == "true" ]]; then
  echo "Resuming refine session for '$BRANCH'"
  echo "branch: $BRANCH"
  echo "base: $BASE"
  echo "pr_number: ${PR_NUMBER:-none}"
  echo "changed_lines: $CHANGED_LINES"
  echo "large_diff: $LARGE_DIFF"
  echo "resuming: true"
  echo "state_file: $STATE_FILE"
  exit 0
fi

SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)

cat > "$STATE_FILE" <<FRONTMATTER
---
session_id: "$SESSION_ID"
status: reviewing
branch: "$BRANCH"
base: "$BASE"
base_sha: "$BASE_SHA"
head_sha: "$HEAD_SHA"
pr_number: ${PR_NUMBER:-null}
changed_lines: $CHANGED_LINES
large_diff: $LARGE_DIFF
total_topics: 0
resolved_topics: 0
deferred_topics: 0
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---
# Refine: $BRANCH

## Topics
(pending chunk)
FRONTMATTER

echo "Refine session prepared for '$BRANCH'"
echo "branch: $BRANCH"
echo "base: $BASE"
echo "pr_number: ${PR_NUMBER:-none}"
echo "changed_lines: $CHANGED_LINES"
echo "large_diff: $LARGE_DIFF"
echo "resuming: false"
echo "state_file: $STATE_FILE"
