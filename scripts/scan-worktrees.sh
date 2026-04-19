#!/bin/bash

# Scan all worktrees of the current repo for vader state files
# Prints one TSV line per session: kind<TAB>worktree_path<TAB>branch<TAB>status<TAB>progress
# kind ∈ {plan, refine}

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

get_field() {
  awk -F': *' -v k="$1" '$1 == k {gsub(/^"|"$/, "", $2); print $2; exit}' "$2"
}

CURRENT_WT=$(git rev-parse --show-toplevel)

# Parse `git worktree list --porcelain` for (worktree, branch) pairs.
WT_PATH=""
WT_BRANCH=""
while IFS= read -r line; do
  if [[ "$line" == worktree\ * ]]; then
    WT_PATH="${line#worktree }"
    WT_BRANCH=""
  elif [[ "$line" == branch\ * ]]; then
    WT_BRANCH="${line#branch refs/heads/}"
  elif [[ -z "$line" && -n "$WT_PATH" ]]; then
    # End of a worktree block — emit any vader state found.
    MARK=""
    if [[ "$WT_PATH" == "$CURRENT_WT" ]]; then MARK="*"; fi

    PLAN="$WT_PATH/.claude/vader/plan.local.md"
    if [[ -f "$PLAN" ]]; then
      S=$(get_field status "$PLAN")
      CUR=$(get_field current_milestone "$PLAN")
      TOT=$(get_field total_milestones "$PLAN")
      printf 'plan\t%s\t%s\t%s\t%s/%s\t%s\n' "$WT_PATH" "${WT_BRANCH:-?}" "${S:-?}" "${CUR:-?}" "${TOT:-?}" "$MARK"
    fi

    REFINE="$WT_PATH/.claude/vader/refine.local.md"
    if [[ -f "$REFINE" ]]; then
      S=$(get_field status "$REFINE")
      RES=$(get_field resolved_topics "$REFINE")
      TOT=$(get_field total_topics "$REFINE")
      printf 'refine\t%s\t%s\t%s\t%s/%s\t%s\n' "$WT_PATH" "${WT_BRANCH:-?}" "${S:-?}" "${RES:-?}" "${TOT:-?}" "$MARK"
    fi

    WT_PATH=""
    WT_BRANCH=""
  fi
done < <(git worktree list --porcelain; echo)
