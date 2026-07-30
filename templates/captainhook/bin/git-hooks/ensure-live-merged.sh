#!/usr/bin/env bash
# CaptainHook post-checkout action.
# On every branch checkout, merges 'live' into the current branch
# if live has commits the branch does not yet contain.
# Skips: live itself, uat, detached HEAD.

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

case "$current_branch" in
    live|uat|HEAD|master|main)
        exit 0
        ;;
esac

live_sha=$(git rev-parse live 2>/dev/null)
if [ -z "$live_sha" ]; then
    exit 0
fi

# live is already an ancestor of HEAD — branch is up-to-date
if git merge-base --is-ancestor live HEAD 2>/dev/null; then
    exit 0
fi

echo ""
echo "Merging 'live' into '$current_branch' (branch is behind live)..."
echo ""

if git merge live --no-edit 2>&1; then
    echo ""
    echo "Merged 'live' into '$current_branch' successfully."
    echo ""
else
    echo ""
    echo "WARNING: Merge of 'live' into '$current_branch' produced conflicts."
    echo "Resolve conflicts, then: git add . && git commit"
    echo ""
fi

# Always exit 0 — checkout succeeded, merge state is the user's to resolve
exit 0
