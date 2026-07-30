#!/usr/bin/env bash
set -euo pipefail

# Simple spinner for long-running steps
spinner() {
  local pid=$1
  local msg=$2
  local spin='|/-\'
  local i=0
  printf "%s " "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\r%s %s" "$msg" "${spin:$i:1}"
    sleep 0.2
  done
  printf "\r%s ... done\n" "$msg"
}

run_step() {
  local message=$1
  shift
  ( eval "$@" ) &
  local cmd_pid=$!
  spinner "$cmd_pid" "$message"
  wait "$cmd_pid"
}

# Determine current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Always inform the user
echo "Pre-push check: pushing to live or mageos requires a full composer install test."

if [ "$BRANCH" = "live" ] || [ "$BRANCH" = "mageos" ]; then
  echo "Detected branch: $BRANCH. This may take several minutes; showing progress..."

  # Ensure we're in project root (script is in bin/)
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  cd "$REPO_ROOT"

  # Step 1: Clear composer cache inside DDEV
  run_step "Clearing Composer cache in DDEV" "composer clear-cache >/dev/null 2>&1 || composer cache:clear >/dev/null 2>&1"

  # Step 2: Remove vendor directory (host filesystem)
  if [ -d vendor ]; then
    run_step "Removing vendor directory" "rm -rf vendor_backup; mv vendor vendor_backup"
  else
    echo "Vendor directory not present, skipping removal."
  fi

  # Step 3: Install composer dependencies inside DDEV
  # Use non-interactive flags to avoid prompts and ensure deterministic install
  run_step "Running composer install in DDEV" "composer install --no-interaction no, bu --no-suggest"

  echo "Verification complete. Proceeding with push."
else
  echo "Branch '$BRANCH' is not live or mageos; skipping heavy verification."
fi
