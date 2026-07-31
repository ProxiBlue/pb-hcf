#!/usr/bin/env bash
# pb-hcf rector-check.sh — deterministic rector dry-run gate for changed custom-code PHP files
#
# Why this exists: task 011 (rector enforcement wiring). This is the DETERMINISTIC layer —
# it fails loud (exit 1 + diff) when rector proposes a transform on changed custom-namespace
# PHP files, and degrades gracefully (exit 0 + install note) when rector isn't installed yet.
# Contested-transform JUDGMENT (is this diff safe to apply?) is NOT this script's job — that
# lives in agents/pre-commit-adversarial-pass.md's rector-diff review step.
#
# Scope convention (SAME as tasks 005/012 — no separate "namespace config" source):
#   git diff --name-only <ref> -- 'app/code/**/*.php'
#   excludes:
#     - generated/            (Magento runtime codegen output — Interceptor/Factory/Proxy, not source)
#     - vendor/                (dependency code, not custom code — outside app/code/** already)
#     - */Test/*/_files/*     (test fixtures — output/data, not source under review)
#
# Usage:
#   scripts/rector-check.sh [ref]      # ref defaults to HEAD; compares working tree to ref
#
# Exit codes:
#   0 — no changed files in scope, OR rector/rector.php absent (degraded — install note printed),
#       OR rector dry-run reports no proposed transforms
#   1 — rector dry-run reports proposed transforms; diff printed to stdout

set -u

REF="${1:-HEAD}"
RECTOR_BIN="vendor/bin/rector"
RECTOR_CONFIG="rector.php"

if [[ ! -x "$RECTOR_BIN" ]]; then
  echo "rector-check: rector not installed (no executable ${RECTOR_BIN})."
  echo "rector-check: install note — composer require --dev rector/rector, then"
  echo "rector-check:   cp templates/rector/rector.php.dist rector.php (see templates/rector/README.md)."
  echo "rector-check: degrading — skipping check, exit 0."
  exit 0
fi

if [[ ! -f "$RECTOR_CONFIG" ]]; then
  echo "rector-check: no ${RECTOR_CONFIG} found at repo root."
  echo "rector-check: install note — cp templates/rector/rector.php.dist rector.php and substitute"
  echo "rector-check:   the <Vendor> placeholder (see templates/rector/README.md)."
  echo "rector-check: degrading — skipping check, exit 0."
  exit 0
fi

mapfile -t CHANGED_FILES < <(git diff --name-only "$REF" -- 'app/code/**/*.php' \
  | grep -v '/generated/' \
  | grep -v '/Test/[^/]*/_files/')

if [[ "${#CHANGED_FILES[@]}" -eq 0 ]]; then
  echo "rector-check: no changed app/code/**/*.php files in scope (excluding generated/ and test fixtures) — nothing to check."
  exit 0
fi

if DIFF_OUTPUT="$("$RECTOR_BIN" process "${CHANGED_FILES[@]}" --dry-run --config="$RECTOR_CONFIG" 2>&1)"; then
  echo "rector-check: no transforms proposed on changed custom-namespace files — clean."
  exit 0
fi

echo "rector-check: rector proposes transforms on changed custom-namespace files:"
echo "$DIFF_OUTPUT"
exit 1
