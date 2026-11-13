#!/usr/bin/env bash
# Proof by revert: run a test with the current change applied (expect pass), then
# without it (expect fail), in a throwaway git worktree. The user's working tree and
# index are never modified. Works for a bug fix or a feature; "fix" below means the
# change under test. Needs git and bash 3.2 or newer, nothing else.
#
# Usage:
#   revert-proof.sh [options] '<test command>' [base-ref]
#   revert-proof.sh [options] -- <test command words...>     (base only via --base)
#
#   base-ref        what "without the fix" means. Default HEAD (uncommitted work only).
#                   With a branch name, the merge-base with HEAD is used.
#   --base REF      same as the positional base-ref
#   --keep PATH     path (file or dir, relative to repo root) that stays applied in BOTH
#                   runs. Use it for a test or repro that is itself part of the change,
#                   otherwise the second run fails because the test is gone, not because
#                   the bug is back. Repeatable. Also: REVERT_PROOF_KEEP=a:b
#   --link DIR      symlink DIR (relative to repo root, e.g. node_modules, .venv, vendor)
#                   from the original tree into the worktree, because ignored dirs are not
#                   in a fresh worktree. Repeatable. Also: REVERT_PROOF_LINK=a:b
#                   The link is the original dir: writes through it land there, and
#                   symlinks inside it that point back into the repo (workspace packages)
#                   still see the fixed code. The script warns when it finds those.
#   --tail N        lines of output shown per run (default 15)
#
# Exit codes:
#   0  proven    passes with the fix, fails without it
#   1  unproven  passes with the fix AND without it, or could not run without it (exit 126/127)
#   2  usage error, not a git repo, or the change could not be applied
#   3  no diff   nothing to prove (no change outside --keep paths)
#   4  broken    fails even with the fix applied (second run skipped)
set -euo pipefail
export GIT_OPTIONAL_LOCKS=0

die() { echo "revert-proof: $*" >&2; exit 2; }
usage() { sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; }

base="HEAD"
tail_n=15
keeps=()
links=()
args=()
dashed_cmd=""

split_env() {
  local IFS=:
  # shellcheck disable=SC2206
  local parts=($1)
  printf '%s\n' ${parts[@]+"${parts[@]}"}
}
if [ -n "${REVERT_PROOF_KEEP:-}" ]; then
  while IFS= read -r p; do [ -n "$p" ] && keeps+=("$p"); done < <(split_env "$REVERT_PROOF_KEEP")
fi
if [ -n "${REVERT_PROOF_LINK:-}" ]; then
  while IFS= read -r p; do [ -n "$p" ] && links+=("$p"); done < <(split_env "$REVERT_PROOF_LINK")
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || die "--base needs a value"; base="$2"; shift 2 ;;
    --keep) [ $# -ge 2 ] || die "--keep needs a value"; keeps+=("${2%/}"); shift 2 ;;
    --link) [ $# -ge 2 ] || die "--link needs a value"; links+=("${2%/}"); shift 2 ;;
    --tail) [ $# -ge 2 ] || die "--tail needs a value"; tail_n="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; [ $# -gt 0 ] || die "nothing after --"; dashed_cmd="$*"; break ;;
    -*) die "unknown option $1 (see --help)" ;;
    *) args+=("$1"); shift ;;
  esac
done

if [ -n "$dashed_cmd" ]; then
  [ ${#args[@]} -eq 0 ] || die "with --, put options before it and the whole command after it (base via --base)"
  cmd="$dashed_cmd"
else
  [ ${#args[@]} -ge 1 ] || { usage >&2; exit 2; }
  [ ${#args[@]} -le 2 ] || die "too many arguments; quote the test command as one string, or put it after --"
  cmd="${args[0]}"
  if [ ${#args[@]} -eq 2 ]; then base="${args[1]}"; fi
fi
[ -n "$cmd" ] || die "empty test command"
case "$tail_n" in ''|*[!0-9]*) die "--tail needs a number" ;; esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository"
repo="$(git rev-parse --show-toplevel)"
cd "$repo"

git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown base ref: $base"
if [ "$base" != "HEAD" ]; then
  base_sha="$(git merge-base "$base" HEAD)" || die "no merge-base between $base and HEAD"
else
  base_sha="$(git rev-parse HEAD)"
fi

for p in ${keeps[@]+"${keeps[@]}"} ${links[@]+"${links[@]}"}; do
  case "$p" in /*|..|../*|*/../*|*/..) die "paths must be relative to the repo root and stay inside it: $p" ;; esac
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/revert-proof.XXXXXX")"
wt="$tmp/wt"
wt_added=0

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  set +e
  cd "$repo" 2>/dev/null
  # Unlink dependency symlinks first so nothing can ever recurse into the original dirs.
  for l in ${links[@]+"${links[@]}"}; do
    [ -L "$wt/$l" ] && rm -f "$wt/$l"
  done
  if [ "$wt_added" = 1 ]; then
    git worktree remove --force "$wt" >/dev/null 2>&1
  fi
  rm -rf "$tmp"
  if [ "$wt_added" = 1 ] && git worktree list --porcelain 2>/dev/null | grep -Fq "$wt"; then
    git worktree prune >/dev/null 2>&1
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

is_kept() {
  local f="$1" k
  for k in ${keeps[@]+"${keeps[@]}"}; do
    [ "$f" = "$k" ] && return 0
    case "$f" in "$k"/*) return 0 ;; esac
  done
  return 1
}

# --- collect the change, read-only -------------------------------------------------
excludes=()
for k in ${keeps[@]+"${keeps[@]}"}; do excludes+=(":(exclude,top)$k"); done

git --no-pager diff --binary --no-color --no-ext-diff "$base_sha" -- . ${excludes[@]+"${excludes[@]}"} > "$tmp/fix.patch"
: > "$tmp/keep.patch"
if [ ${#keeps[@]} -gt 0 ]; then
  git --no-pager diff --binary --no-color --no-ext-diff "$base_sha" -- "${keeps[@]}" > "$tmp/keep.patch"
fi

: > "$tmp/untracked.fix"; : > "$tmp/untracked.keep"
n_fix_untracked=0; n_keep_untracked=0; skipped_dirs=0
while IFS= read -r -d '' f; do
  if [ -d "$f" ] && [ ! -L "$f" ]; then skipped_dirs=$((skipped_dirs + 1)); continue; fi
  if is_kept "$f"; then
    printf '%s\0' "$f" >> "$tmp/untracked.keep"; n_keep_untracked=$((n_keep_untracked + 1))
  else
    printf '%s\0' "$f" >> "$tmp/untracked.fix"; n_fix_untracked=$((n_fix_untracked + 1))
  fi
done < <(git ls-files --others --exclude-standard -z)

n_fix_tracked="$(git --no-pager diff --name-only "$base_sha" -- . ${excludes[@]+"${excludes[@]}"} | wc -l | tr -d ' ')"

if [ ! -s "$tmp/fix.patch" ] && [ "$n_fix_untracked" -eq 0 ]; then
  echo "revert-proof: NO DIFF against ${base_sha:0:7}$( [ ${#keeps[@]} -gt 0 ] && echo ' outside the --keep paths' ). Nothing to prove."
  exit 3
fi

# --- scratch worktree at base ------------------------------------------------------
git -c core.hooksPath=/dev/null worktree add --detach --quiet "$wt" "$base_sha" >/dev/null 2>"$tmp/wt.err" \
  || die "could not create worktree: $(cat "$tmp/wt.err")"
wt_added=1

copy_list() {
  local f
  while IFS= read -r -d '' f; do
    mkdir -p "$wt/$(dirname "$f")"
    cp -pR "$repo/$f" "$wt/$f"
  done < "$1"
}
apply_patch() {
  [ -s "$1" ] || return 0
  git -C "$wt" apply --whitespace=nowarn "$1" 2>"$tmp/apply.err" \
    || die "could not apply $(basename "$1") in the worktree: $(cat "$tmp/apply.err")"
}
make_links() {
  local l
  for l in ${links[@]+"${links[@]}"}; do
    if [ ! -e "$repo/$l" ]; then echo "note: --link $l does not exist in the original tree, skipped"; continue; fi
    if [ -e "$wt/$l" ] || [ -L "$wt/$l" ]; then
      [ -L "$wt/$l" ] || echo "note: --link $l already exists in the worktree (tracked), not linked"
      continue
    fi
    mkdir -p "$wt/$(dirname "$l")"
    ln -s "$repo/$l" "$wt/$l"
  done
}
# A linked dir is the original one. If it holds symlinks back into the repo (workspace
# packages in node_modules, editable installs in a venv), those resolve to the ORIGINAL tree, where the fix is still
# applied, so the "without fix" run would partly run fixed code.
check_link_leaks() {
  local l p tgt real ldir repo_real n=0
  repo_real="$(cd "$repo" && pwd -P)"
  : > "$tmp/link.warn"
  for l in ${links[@]+"${links[@]}"}; do
    [ -d "$repo/$l" ] || continue
    ldir="$(cd "$repo/$l" && pwd -P)"
    while IFS= read -r -d '' p; do
      if [ -d "$p" ]; then
        real="$(cd "$p" 2>/dev/null && pwd -P)" || continue
      else
        tgt="$(readlink "$p")"
        real="$(cd "$(dirname "$p")" 2>/dev/null && cd "$(dirname "$tgt")" 2>/dev/null && pwd -P)" || continue
      fi
      case "$real/" in
        "$ldir"/*) ;;
        "$repo_real"/*) n=$((n + 1)); [ "$n" -le 3 ] && echo "    ${p#$repo/} -> ${real#$repo_real/}" >> "$tmp/link.warn" ;;
      esac
    done < <(find "$repo/$l" -maxdepth 3 -type l -print0 2>/dev/null)
  done
  link_leaks=$n
}
drop_links() {
  local l
  for l in ${links[@]+"${links[@]}"}; do
    if [ -L "$wt/$l" ]; then rm -f "$wt/$l"; fi
  done
}
run_cmd() {
  local log="$1" rc=0 start=$SECONDS
  set +e
  ( cd "$wt" && REVERT_PROOF_ORIG="$repo" bash -c "$cmd" ) >"$log" 2>&1 </dev/null
  rc=$?
  set -e
  run_rc=$rc; run_secs=$((SECONDS - start))
}
show_tail() {
  echo "--- $1 (last $tail_n lines) ---"
  if [ -s "$2" ]; then tail -n "$tail_n" "$2" | sed 's/^/  | /'; else echo "  | (no output)"; fi
}

# --- run 1: with the fix -----------------------------------------------------------
apply_patch "$tmp/keep.patch"; copy_list "$tmp/untracked.keep"
apply_patch "$tmp/fix.patch";  copy_list "$tmp/untracked.fix"
make_links
link_leaks=0; check_link_leaks
run_cmd "$tmp/with.log"; rc1=$run_rc; t1=$run_secs

# --- run 2: without the fix (kept paths stay) --------------------------------------
rc2="-"; t2="-"; res2="SKIPPED"
if [ "$rc1" -eq 0 ]; then
  drop_links
  git -C "$wt" reset --hard --quiet
  git -C "$wt" clean -fdq
  apply_patch "$tmp/keep.patch"; copy_list "$tmp/untracked.keep"
  make_links
  run_cmd "$tmp/without.log"; rc2=$run_rc; t2="${run_secs}s"
  if [ "$rc2" -eq 0 ]; then res2="PASS"; else res2="FAIL"; fi
fi
if [ "$rc1" -eq 0 ]; then res1="PASS"; else res1="FAIL"; fi

# --- report ------------------------------------------------------------------------
echo "revert-proof"
echo "  command: $cmd"
echo "  base:    ${base_sha:0:7}   change: $n_fix_tracked tracked, $n_fix_untracked untracked file(s)"
if [ ${#keeps[@]} -gt 0 ]; then echo "  kept in both runs: ${keeps[*]} ($n_keep_untracked untracked)"; fi
if [ ${#links[@]} -gt 0 ]; then echo "  linked from original tree: ${links[*]}"; fi
if [ "$skipped_dirs" -gt 0 ]; then echo "  note: $skipped_dirs untracked nested repo dir(s) not copied"; fi
if [ "$link_leaks" -gt 0 ]; then
  echo "  WARNING: $link_leaks symlink(s) in linked dirs point back into the original tree, where the fix"
  echo "           is still applied. Code reached through them is NOT reverted in the second run:"
  cat "$tmp/link.warn"
fi
echo
printf '%-13s %-7s %-8s %-5s %s\n' "RUN" "EXPECT" "RESULT" "EXIT" "TIME"
printf '%-13s %-7s %-8s %-5s %s\n' "with fix" "pass" "$res1" "$rc1" "${t1}s"
printf '%-13s %-7s %-8s %-5s %s\n' "without fix" "fail" "$res2" "$rc2" "$t2"
echo

if [ "$rc1" -ne 0 ]; then
  echo "VERDICT: BROKEN. The command fails even with the fix applied, so nothing is proven."
  echo "         Check the output: a missing dependency (--link) or env file looks the same as a real failure."
  show_tail "with fix" "$tmp/with.log"
  exit 4
elif [ "$rc2" -eq 126 ] || [ "$rc2" -eq 127 ]; then
  echo "VERDICT: UNPROVEN. Without the fix the command could not run at all (exit $rc2), which is not the bug coming back."
  echo "         If the test or repro is part of the change, pass it with --keep so it stays in both runs."
  show_tail "without fix" "$tmp/without.log"
  exit 1
elif [ "$rc2" -eq 0 ]; then
  echo "VERDICT: UNPROVEN. The command passes with and without the fix, so it does not show the fix does anything."
  show_tail "without fix" "$tmp/without.log"
  exit 1
else
  echo "VERDICT: PROVEN, if the failure below is the original symptom and not a missing file or crash."
  show_tail "without fix" "$tmp/without.log"
  exit 0
fi
