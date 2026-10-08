#!/usr/bin/env bash
# pb-hcf ruff-check.sh — deterministic ruff dry-run gate for changed Python files
#
# Python-stack sibling of scripts/rector-check.sh (same contract, same exit codes). This is the
# DETERMINISTIC layer — it fails loud (exit 1 + diff) when ruff proposes a fix on changed .py
# files, and degrades gracefully (exit 0 + install note) when ruff isn't installed.
# Contested-fix JUDGMENT (is this diff safe to apply?) is NOT this script's job — that lives in
# agents/pre-commit-adversarial-pass.md's lint-diff review step.
#
# Rules come from the project's own ruff config (pyproject.toml [tool.ruff] / ruff.toml). To get
# rector-equivalent modernization proposals, enable pyupgrade rules there: select = [..., "UP"].
#
# Scope convention (mirrors rector-check.sh):
#   git diff --name-only --diff-filter=ACMR <ref> -- '*.py'
#   excludes:
#     - .venv/ / venv/ / site-packages/   (dependency code, not project code)
#     - generated protobuf stubs (*_pb2.py, *_pb2_grpc.py)
#
# Usage:
#   scripts/ruff-check.sh [ref]      # ref defaults to HEAD; compares working tree to ref
#
# Exit codes:
#   0 — no changed files in scope, OR ruff absent (degraded — install note printed),
#       OR ruff proposes no fixes
#   1 — ruff proposes fixes; diff printed to stdout

set -u

REF="${1:-HEAD}"

RUFF=()
if [[ -x ".venv/bin/ruff" ]]; then
  RUFF=(".venv/bin/ruff")
elif command -v ruff >/dev/null 2>&1; then
  RUFF=("ruff")
elif command -v uv >/dev/null 2>&1 && [[ -f uv.lock ]] && uv run --no-sync ruff --version >/dev/null 2>&1; then
  RUFF=("uv" "run" "--no-sync" "ruff")
fi

if [[ "${#RUFF[@]}" -eq 0 ]]; then
  echo "ruff-check: ruff not installed (no .venv/bin/ruff, no ruff on PATH, not in uv env)."
  echo "ruff-check: install note — uv add --dev ruff (or pip install ruff into .venv), then"
  echo "ruff-check:   add [tool.ruff.lint] select = [\"E\", \"F\", \"B\", \"UP\", \"S\"] to pyproject.toml."
  echo "ruff-check: degrading — skipping check, exit 0."
  exit 0
fi

mapfile -t CHANGED_FILES < <(git diff --name-only --diff-filter=ACMR "$REF" -- '*.py' \
  | grep -vE '(^|/)(\.venv|venv|site-packages)/' \
  | grep -vE '_pb2(_grpc)?\.py$')

if [[ "${#CHANGED_FILES[@]}" -eq 0 ]]; then
  echo "ruff-check: no changed *.py files in scope (excluding venvs and generated stubs) — nothing to check."
  exit 0
fi

if DIFF_OUTPUT="$("${RUFF[@]}" check --diff "${CHANGED_FILES[@]}" 2>&1)"; then
  echo "ruff-check: no fixes proposed on changed Python files — clean."
  exit 0
fi

echo "ruff-check: ruff proposes fixes on changed Python files:"
echo "$DIFF_OUTPUT"
exit 1
