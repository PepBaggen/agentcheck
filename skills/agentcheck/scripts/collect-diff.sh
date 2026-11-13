#!/usr/bin/env bash
# Read-only snapshot of what changed in a git repo. Changes nothing. bash 3.2 or newer.
#
# Usage:
#   collect-diff.sh [base-ref]                      status, diff --stat, untracked file names with sizes
#   collect-diff.sh [base-ref] --diff [paths...]    unified diff, optionally only these paths, capped
#   collect-diff.sh --show <file>                   one new (untracked) text file, capped
#
#   base-ref   default HEAD (uncommitted work only). With a branch name the merge-base
#              with HEAD is used, so later commits on the base do not show up reversed.
#   paths      relative to the repo root, as printed by the default output.
#
# Caps: COLLECT_DIFF_MAX_LINES (default 400), COLLECT_DIFF_MAX_BYTES (default 4000),
#       COLLECT_DIFF_MAX_UNTRACKED (default 40 names).
set -euo pipefail
max_lines="${COLLECT_DIFF_MAX_LINES:-400}"
max_bytes="${COLLECT_DIFF_MAX_BYTES:-4000}"
max_untracked="${COLLECT_DIFF_MAX_UNTRACKED:-40}"

die() { echo "collect-diff: $*" >&2; exit 2; }

base="HEAD"
mode="stat"
show=""
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --diff) mode="diff"; shift
            while [ $# -gt 0 ]; do [ "$1" = "--" ] || paths+=("$1"); shift; done ;;
    --show) [ $# -ge 2 ] || die "--show needs a file"; mode="show"; show="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) base="$1"; shift ;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository"
cd "$(git rev-parse --show-toplevel)"

is_text() { grep -Iq . "$1" 2>/dev/null; }
size_of() { wc -c < "$1" | tr -d ' '; }

if [ "$mode" = "show" ]; then
  [ -f "$show" ] || die "no such file (paths are relative to the repo root): $show"
  size=$(size_of "$show")
  if ! is_text "$show"; then
    echo "## $show (binary or empty, $size bytes, not shown)"
  elif [ "$size" -gt "$max_bytes" ]; then
    echo "## $show ($size bytes, first $max_bytes shown)"
    head -c "$max_bytes" "$show"; echo
    echo "... cut $((size - max_bytes)) of $size bytes. Read a line range of the file for more."
  else
    echo "## $show ($size bytes)"
    cat "$show"; echo
  fi
  exit 0
fi

if [ "$base" != "HEAD" ]; then
  base_arg="$base"
  base="$(git merge-base "$base_arg" HEAD 2>/dev/null)" || die "no merge-base between $base_arg and HEAD"
fi

if [ "$mode" = "diff" ]; then
  echo "## DIFF (against ${base:0:12})"
  git --no-pager diff --no-color "$base" -- ${paths[@]+"${paths[@]}"} | awk -v max="$max_lines" '
    NR <= max { print }
    END {
      if (NR == 0) print "(no tracked changes here; a new untracked file is read with --show <file>)"
      if (NR > max) printf "... cut %d of %d lines. Narrow it: --diff <path>\n", NR - max, NR
    }'
  exit 0
fi

echo "## STATUS"
git status --short

echo
echo "## STAT (against ${base:0:12})"
git --no-pager diff --stat=200 "$base" --

echo
echo "## UNTRACKED (names only; read one with --show <file>)"
total=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
git ls-files --others --exclude-standard | awk -v max="$max_untracked" 'NR <= max' |
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if is_text "$f"; then kind="text"; else kind="binary or empty"; fi
  echo "$f ($(size_of "$f") bytes, $kind)"
done
if [ "$total" -gt "$max_untracked" ]; then
  echo "... and $((total - max_untracked)) more untracked files not listed"
fi
