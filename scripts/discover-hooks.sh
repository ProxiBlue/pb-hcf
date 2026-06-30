#!/usr/bin/env bash
# pb-hcf discover-hooks.sh — deterministic HCF v2 hook agent enumeration
#
# Why this exists: HCF v2's hook discovery routine (HOOKS.md) is described as
# instructions for the LLM to follow. The in-session Claude improvises a bash
# enumeration script on the fly. That improvised script can have syntax bugs.
# PPS 2026-06-30: invalid `for f in $LOC/*.md 2>/dev/null` crashed at line 35,
# partial output was consumed as ground truth, all hooks reported empty even
# though 13 agent files were correctly stocked with `phase:` frontmatter.
#
# This script makes the discovery routine deterministic — single source of
# truth, awk-parsed, exit-code-checked. Use as:
#   - manual sanity check before /hcf:plan-create
#   - SessionStart hook (hooks/discover-hooks.sh wraps + emits to context)
#   - upstream candidate for HCF itself (so plan-create calls it instead of
#     asking Claude to improvise)
#
# Usage:
#   discover-hooks.sh                       # all 8 hooks
#   discover-hooks.sh --hook=pre-plan       # one hook only
#   discover-hooks.sh --target=<host-path>  # override agent dir auto-detect
#   discover-hooks.sh --json                # machine-readable output
#
# Output: resolved-order table per hook (or JSON if --json).
# Exit codes: 0 success (incl. empty hooks); 1 target dir missing; 2 bad args.

set -e -o pipefail

HOOK_FILTER=""
TARGET=""
JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hook=*)   HOOK_FILTER="${1#*=}" ;;
    --target=*) TARGET="${1#*=}" ;;
    --json)     JSON=1 ;;
    -h|--help)  sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# Auto-detect target directory.
#
# Context matters: this script runs both from HOST (where the mount source —
# typically ~/claude-code-magento-agents — IS writable) and from inside the
# DDEV container (where the same agents are visible at .claude/agents/ via the
# RO mount; the host-side source path is irrelevant inside the container).
#
# Detection order:
#   1. --target=<path> flag — explicit override.
#   2. Project-local .claude/agents/ — if it exists and contains .md files. This
#      catches the container-side case (where the RO mount makes the agents
#      visible at this path) AND the host-side non-fleet-mount case (project-
#      local agent files written directly).
#   3. Parse .ddev/docker-compose*.yaml for the agents mount source — IF the
#      detected source path exists on disk (host-side case where mount source
#      lives outside the project).
#   4. Fall back to .claude/agents/ even if empty — caller sees "all empty"
#      enumeration rather than an error.
if [[ -z "$TARGET" ]]; then
  if [[ -d ".claude/agents" && -n "$(ls .claude/agents/*.md 2>/dev/null)" ]]; then
    TARGET=".claude/agents"
  else
    for f in .ddev/docker-compose*.yaml; do
      [[ -f "$f" ]] || continue
      src=$(grep -E ':/var/www/html/\.claude/agents:r[ow]' "$f" 2>/dev/null \
            | head -1 \
            | sed -E 's/^[[:space:]]*-[[:space:]]*"?([^:"]+):.*$/\1/')
      if [[ -n "$src" ]]; then
        candidate=$(eval echo "$src")  # expand $HOME, $USER, etc.
        if [[ -d "$candidate" ]]; then
          TARGET="$candidate"
          break
        fi
      fi
    done
  fi
fi
[[ -z "$TARGET" ]] && TARGET=".claude/agents"

if [[ ! -d "$TARGET" ]]; then
  echo "discover-hooks: target directory not found (project root '$(pwd)' has no .claude/agents/ and no ddev mount source resolves to an existing path)" >&2
  exit 1
fi

# Enumerate .md files at top level (HCF's flat glob — does NOT recurse).
# Parse YAML frontmatter (between first two `---` lines) for phase / order / mode.
names=()
phases=()
orders=()
modes=()

while IFS= read -r f; do
  base=$(basename "$f")
  phase=$(awk '/^---$/{c++; next} c==1 && /^phase:[[:space:]]*/{sub(/^phase:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$f")
  order=$(awk '/^---$/{c++; next} c==1 && /^order:[[:space:]]*/{sub(/^order:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$f")
  mode=$(awk '/^---$/{c++; next} c==1 && /^mode:[[:space:]]*/{sub(/^mode:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$f")

  [[ -z "$phase" ]] && continue   # no phase = not enrolled, skip
  [[ -n "$HOOK_FILTER" && "$phase" != "$HOOK_FILTER" ]] && continue

  names+=("$base")
  phases+=("$phase")
  orders+=("${order:-100}")  # HCF default
  modes+=("${mode:-single}")
done < <(ls "$TARGET"/*.md 2>/dev/null | sort)

ALL_HOOKS="pre-plan post-plan pre-implementation pre-batch post-batch post-implementation pre-commit post-commit"
HOOKS_TO_PRINT=${HOOK_FILTER:-$ALL_HOOKS}

if [[ -n "$JSON" ]]; then
  # JSON output for machine consumption
  printf '{"target":"%s","hooks":{' "$TARGET"
  sep=""
  for hook in $HOOKS_TO_PRINT; do
    printf '%s"%s":[' "$sep" "$hook"
    item_sep=""
    # collect indices + sort by order asc, name asc
    for i in "${!names[@]}"; do
      [[ "${phases[$i]}" == "$hook" ]] || continue
      printf "%s|%s|%s|%s\n" "${orders[$i]}" "${names[$i]}" "${modes[$i]}" "$i"
    done | sort -t'|' -k1,1n -k2,2 | while IFS='|' read -r ord nm md _; do
      printf '%s{"name":"%s","order":%d,"mode":"%s"}' "$item_sep" "${nm%.md}" "$ord" "$md"
      item_sep=","
    done
    printf ']'
    sep=","
  done
  printf '}}'
  echo
  exit 0
fi

# Human-readable output (matches HCF's resolved-order line format)
echo "# pb-hcf hook discovery"
echo "# target: $TARGET"
echo "# generated by: scripts/discover-hooks.sh"
echo ""

for hook in $HOOKS_TO_PRINT; do
  count=0
  for i in "${!names[@]}"; do
    [[ "${phases[$i]}" == "$hook" ]] && count=$((count+1))
  done

  echo "## $hook"
  if [[ $count -eq 0 ]]; then
    echo "  (empty — no agents enrolled at this hook)"
  else
    for i in "${!names[@]}"; do
      [[ "${phases[$i]}" == "$hook" ]] || continue
      printf "%s|%s|%s\n" "${orders[$i]}" "${names[$i]}" "${modes[$i]}"
    done | sort -t'|' -k1,1n -k2,2 | while IFS='|' read -r ord nm md; do
      printf "  order=%-4d  %-45s  mode=%s\n" "$ord" "${nm%.md}" "$md"
    done
  fi
  echo ""
done
