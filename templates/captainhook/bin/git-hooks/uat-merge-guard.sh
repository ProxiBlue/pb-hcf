#!/usr/bin/env bash
# CaptainHook pre-commit action.
# Blocks committing a merge where the source is 'uat'.
# MERGE_HEAD is only set during an in-progress merge commit — safe to run on every pre-commit.

MERGE_HEAD_FILE=".git/MERGE_HEAD"

# Not a merge commit — nothing to do
if [ ! -f "$MERGE_HEAD_FILE" ]; then
    exit 0
fi

merge_head=$(cat "$MERGE_HEAD_FILE")
uat_sha=$(git rev-parse uat 2>/dev/null)

if [ -z "$uat_sha" ]; then
    exit 0
fi

if [ "$merge_head" = "$uat_sha" ]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo ""
    echo "BLOCKED: merging 'uat' into '$current_branch' is not allowed."
    echo "'uat' is a testing environment — merge feature branches individually."
    echo ""
    echo "To abort this merge: git merge --abort"
    echo ""
    exit 1
fi
