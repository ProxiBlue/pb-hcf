#!/usr/bin/env bash
# pb-hcf composer-drift-check.sh — deterministic, read-only composer drift gate.
#
# Why this exists: a plan run must not silently change dependency state. Two
# incidents shaped it:
#   - pvcpipesupplies 2026-07-28: a `composer install` silently pruned a theme
#     package out of vendor/ and a checkout block went blank.
#   - pvcpipesupplies #351, 2026-08-05: the "did composer drift?" question was
#     written into the plan as a task and handed to a tdd-worker. The worker
#     improvised its own verification, ran `git stash`, and wiped three
#     finished tasks' uncommitted work.
# The check is the same every time, so it is a script, not a task for an agent
# to improvise. Whether a reported change was INTENDED by the plan is not this
# script's job — that is agents/pre-commit-composer-drift.md.
#
# What it checks (never writes, never runs a composer command that changes state):
#   1. composer.lock in the working tree vs <ref>: packages removed, added, or
#      changed version (packages + packages-dev).
#   2. vendor/ vs composer.lock, via `composer install --dry-run`: any pending
#      install/removal/upgrade means vendor/ is not what the lock says, and a
#      stale-lock warning means composer.json moved without the lock.
#
# Usage:
#   scripts/composer-drift-check.sh [ref]
#     ref: what to compare the working tree against. Default: HEAD — in a plan
#          run nothing is committed until the end, so HEAD..working-tree is
#          exactly what the run changed. Pass a merge-base (or set
#          COMPOSER_DRIFT_BASE) to cover the whole branch instead.
#
# Environment:
#   COMPOSER_DRIFT_BASE      default ref when no argument is given
#   COMPOSER_DRIFT_TIMEOUT   seconds allowed for the composer dry-run (default 180)
#   COMPOSER_DRIFT_NO_VENDOR set to 1 to skip check 2
#
# Exit codes:
#   0 — no drift (or no composer.json: nothing to check)
#   1 — drift found; report on stdout
#   2 — could not check (not a git repo, bad ref, no jq, unreadable lock,
#       composer dry-run failed); reason on stderr. Never treat 2 as a pass.

set -u
set -o pipefail   # a jq parse failure must not be hidden by the sort after it

REF="${1:-${COMPOSER_DRIFT_BASE:-HEAD}}"
TIMEOUT_SECS="${COMPOSER_DRIFT_TIMEOUT:-180}"

cannot() { echo "composer-drift: CANNOT CHECK — $*" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || cannot "not inside a git repository"
cd "$ROOT" || cannot "cannot cd to $ROOT"

if [[ ! -f composer.json ]]; then
  echo "composer-drift: no composer.json at repo root — nothing to check."
  exit 0
fi

git rev-parse --verify --quiet "${REF}^{commit}" >/dev/null || cannot "ref '${REF}' is not a commit"
command -v jq >/dev/null 2>&1 || cannot "jq is not installed"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/composer-drift.XXXXXX")" || cannot "mktemp failed"
trap 'rm -rf "$TMP"' EXIT

# name<TAB>version for every locked package, sorted by name. Empty input = no packages.
lock_map() {
  jq -r '[(.packages // []), (."packages-dev" // [])] | add | .[] | "\(.name)\t\(.version)"' | LC_ALL=C sort
}

if git cat-file -e "${REF}:composer.lock" 2>/dev/null; then
  git show "${REF}:composer.lock" | lock_map > "$TMP/old" || cannot "composer.lock at ${REF} is not valid JSON"
else
  : > "$TMP/old"
fi

if [[ -f composer.lock ]]; then
  lock_map < composer.lock > "$TMP/new" || cannot "composer.lock in the working tree is not valid JSON"
else
  : > "$TMP/new"
fi

DRIFT=0
SHORT="$(git rev-parse --short "${REF}^{commit}")"
echo "composer-drift: comparing working tree to ${REF} (${SHORT})"

# --- check 1: lock diff -------------------------------------------------------
LC_ALL=C awk -F'\t' '
  NR == FNR { old[$1] = $2; next }
  { new[$1] = $2 }
  END {
    for (p in old) if (!(p in new)) print "REMOVED\t" p "\t" old[p]
    for (p in new) if (!(p in old)) print "ADDED\t" p "\t" new[p]
    for (p in new) if ((p in old) && old[p] != new[p]) print "CHANGED\t" p "\t" old[p] " -> " new[p]
  }' "$TMP/old" "$TMP/new" | LC_ALL=C sort > "$TMP/lockdiff"

if [[ -s "$TMP/lockdiff" ]]; then
  DRIFT=1
  removed="$(grep -c '^REMOVED' "$TMP/lockdiff")"
  added="$(grep -c '^ADDED' "$TMP/lockdiff")"
  changed="$(grep -c '^CHANGED' "$TMP/lockdiff")"
  echo "composer-drift: composer.lock — ${removed} removed, ${added} added, ${changed} changed:"
  awk -F'\t' '{ printf "  %-8s %s %s\n", $1, $2, $3 }' "$TMP/lockdiff"
else
  echo "composer-drift: composer.lock — no package removed, added or changed."
fi

if ! git diff --quiet "$REF" -- composer.json 2>/dev/null; then
  echo "composer-drift: note — composer.json differs from ${REF}."
fi

# --- check 2: vendor/ vs lock -------------------------------------------------
if [[ "${COMPOSER_DRIFT_NO_VENDOR:-0}" == "1" ]]; then
  echo "composer-drift: vendor check skipped (COMPOSER_DRIFT_NO_VENDOR=1)."
elif [[ ! -f composer.lock || ! -d vendor ]]; then
  echo "composer-drift: vendor check skipped (no composer.lock or no vendor/ here)."
elif ! command -v composer >/dev/null 2>&1; then
  echo "composer-drift: vendor check skipped (composer not on PATH — run this where the project's composer runs)."
else
  timeout "$TIMEOUT_SECS" composer install --dry-run --no-interaction --no-scripts > "$TMP/dry" 2>&1
  rc=$?
  if [[ $rc -ne 0 ]]; then
    tail -n 15 "$TMP/dry" >&2
    cannot "composer install --dry-run exited ${rc} (output above)"
  fi
  grep -E '^[[:space:]]*- (Installing|Removing|Upgrading|Downgrading|Updating) ' "$TMP/dry" > "$TMP/ops" || true
  grep -i 'lock file is not up to date' "$TMP/dry" > "$TMP/stale" || true
  if [[ -s "$TMP/ops" ]]; then
    DRIFT=1
    echo "composer-drift: vendor/ does not match composer.lock — a composer install would do this:"
    sed -E 's/^[[:space:]]*/  /' "$TMP/ops"
  else
    echo "composer-drift: vendor/ matches composer.lock."
  fi
  if [[ -s "$TMP/stale" ]]; then
    DRIFT=1
    echo "composer-drift: composer.lock is out of date with composer.json (composer's own warning)."
  fi
fi

if [[ $DRIFT -eq 1 ]]; then
  echo "composer-drift: DRIFT"
  exit 1
fi
echo "composer-drift: clean"
exit 0
