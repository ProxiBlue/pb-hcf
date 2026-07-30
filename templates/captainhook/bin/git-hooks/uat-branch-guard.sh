#!/usr/bin/env bash
# CaptainHook post-checkout action.
# Blocks creating a new branch whose starting point is 'uat'.
# Detects: current branch != uat, but HEAD == uat's tip SHA.
# Undoes the branch creation and prints instructions.

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
head_sha=$(git rev-parse HEAD 2>/dev/null)
uat_sha=$(git rev-parse uat 2>/dev/null)

# Allow: detached HEAD, on uat itself, or uat branch doesn't exist
if [ "$current_branch" = "HEAD" ] || [ "$current_branch" = "uat" ] || [ -z "$uat_sha" ]; then
    exit 0
fi

if [ "$head_sha" = "$uat_sha" ]; then
    echo ""
    echo "BLOCKED: '$current_branch' was created from 'uat'. Branching from UAT is not allowed."
    echo "Branch from 'live' instead:"
    echo "  git checkout live && git checkout -b '$current_branch'"
    echo ""
    git checkout - 2>/dev/null
    git branch -D "$current_branch" 2>/dev/null
    exit 1
fi
