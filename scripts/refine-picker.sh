#!/bin/bash

# List refine candidates (PRs + feature branches) with worktree/refine state.
# Or resolve a picked branch to a worktree path.
#
# Usage:
#   refine-picker.sh list                  # TSV: branch<TAB>pr<TAB>title<TAB>worktree<TAB>refine_state
#   refine-picker.sh resolve <branch>      # prints worktree path, or "NONE:<suggested-path>"
#   refine-picker.sh create <branch> <path>  # git worktree add <path> <branch>

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

default_branch() {
  if git show-ref --verify --quiet refs/remotes/origin/main; then echo main
  elif git show-ref --verify --quiet refs/remotes/origin/master; then echo master
  elif git show-ref --verify --quiet refs/heads/main; then echo main
  elif git show-ref --verify --quiet refs/heads/master; then echo master
  else echo "" ; fi
}

# Map branch -> worktree path from `git worktree list --porcelain`.
worktree_for_branch() {
  local target="$1"
  local wt=""
  local br=""
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt="${line#worktree }"
      br=""
    elif [[ "$line" == branch\ * ]]; then
      br="${line#branch refs/heads/}"
      if [[ "$br" == "$target" ]]; then
        echo "$wt"
        return 0
      fi
    fi
  done < <(git worktree list --porcelain)
  return 1
}

refine_state_for() {
  local wt="$1"
  local f="$wt/.claude/vader/refine.local.md"
  if [[ ! -f "$f" ]]; then return; fi
  local status res tot
  status=$(awk -F': *' '$1 == "status" {gsub(/^"|"$/, "", $2); print $2; exit}' "$f")
  res=$(awk -F': *' '$1 == "resolved_topics" {print $2; exit}' "$f")
  tot=$(awk -F': *' '$1 == "total_topics" {print $2; exit}' "$f")
  if [[ -z "$status" ]]; then return; fi
  if [[ "${tot:-0}" -gt 0 ]]; then
    echo "${status} (${res:-0}/${tot})"
  else
    echo "$status"
  fi
}

cmd_list() {
  local def
  def=$(default_branch)
  if [[ -z "$def" ]]; then
    echo "Error: no default branch (main/master) detected" >&2
    exit 1
  fi

  # Collect candidates as "branch|pr|title" lines in a temp file.
  local tmp
  tmp=$(mktemp)

  if command -v gh >/dev/null 2>&1; then
    local prs
    prs=$(gh pr list --author @me --state open --json number,headRefName,title --limit 50 2>/dev/null || true)
    if [[ -n "$prs" && "$prs" != "[]" ]]; then
      echo "$prs" | jq -r '.[] | [.headRefName, (.number|tostring), .title] | @tsv' \
        | awk -F'\t' -v OFS='|' 'NF>=2 && $1 != "" {print $1, $2, $3}' >> "$tmp"
    fi
  fi

  # Local feature branches with unmerged commits vs default branch.
  local base_ref=""
  if git show-ref --verify --quiet "refs/remotes/origin/$def"; then
    base_ref="origin/$def"
  else
    base_ref="$def"
  fi

  while IFS= read -r br; do
    [[ -z "$br" || "$br" == "$def" ]] && continue
    local ahead
    ahead=$(git rev-list --count "$base_ref..$br" 2>/dev/null || echo 0)
    if [[ "$ahead" -gt 0 ]]; then
      # Append only if not already listed from PRs.
      if ! awk -F'|' -v b="$br" '$1 == b {found=1; exit} END {exit !found}' "$tmp"; then
        printf '%s||\n' "$br" >> "$tmp"
      fi
    fi
  done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

  sort -u "$tmp" | while IFS='|' read -r br pr title; do
    [[ -z "$br" ]] && continue
    local wt=""
    wt=$(worktree_for_branch "$br" || true)
    local state=""
    if [[ -n "$wt" ]]; then
      state=$(refine_state_for "$wt")
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$br" "$pr" "$title" "$wt" "$state"
  done

  rm -f "$tmp"
}

cmd_resolve() {
  local branch="${1:?branch required}"
  local wt=""
  wt=$(worktree_for_branch "$branch" || true)
  if [[ -n "$wt" ]]; then
    echo "$wt"
    return 0
  fi
  # Suggest a sibling path next to the main worktree.
  local main_wt
  main_wt=$(git worktree list --porcelain | awk '$1 == "worktree" {print $2; exit}')
  local repo_name
  repo_name=$(basename "$main_wt")
  local safe_branch
  safe_branch=$(echo "$branch" | tr '/' '-' | tr -cd '[:alnum:]._-')
  local suggested
  suggested="$(dirname "$main_wt")/${repo_name}-${safe_branch}"
  echo "NONE:$suggested"
}

cmd_create() {
  local branch="${1:?branch required}"
  local path="${2:?path required}"
  if [[ -e "$path" ]]; then
    echo "Error: path already exists: $path" >&2
    exit 1
  fi
  git worktree add "$path" "$branch"
  echo "$path"
}

case "${1:-}" in
  list) shift; cmd_list "$@" ;;
  resolve) shift; cmd_resolve "$@" ;;
  create) shift; cmd_create "$@" ;;
  *) echo "Usage: $0 {list|resolve <branch>|create <branch> <path>}" >&2; exit 2 ;;
esac
