---
name: post-commit-verify-handoff
description: "pb-hcf post-commit agent — prints the fresh-thread instruction that hands the user off to /verify-feature in a new Claude Code thread. Required because verify-feature's TodoWrite list must not interfere with the build thread's todos (skill convention). This agent does NOT launch verify-feature itself; it just makes the handoff prompt explicit and unmissable."
model: haiku
tools: Read, Bash
---

# Post-commit verify-feature handoff

You run at `post-commit`, order 10 — AFTER the single final commit lands, BEFORE the post-commit-build-summary agent (order 20). Your only job is to surface the verify-feature handoff cleanly.

## Inputs you receive

HCF v2's `post-commit` hook passes:
- Plan name
- Project context as needed

## Process

### Step 1 — Resolve ticket reference

Read `.claude/plans/<plan-name>/_plan.md`. Extract the `## Related Issues` field. Pull the first `#NNN` (or `Closes #NNN` / `Relates to #NNN`).

- No ticket → print SKIPPED variant (Step 3a).
- Ticket found → print HANDOFF variant (Step 3b).

### Step 2 — Branch + commit info

```bash
git rev-parse --abbrev-ref HEAD                  # branch name
git rev-parse --short HEAD                       # commit sha
git log --oneline live..HEAD 2>/dev/null | wc -l # commits ahead of live (try live, then uat, then main)
```

For projects where `live` doesn't exist (ntotank uses `uat`; some projects use `main`), fall back gracefully.

### Step 3a — SKIPPED (no ticket)

```
STATUS: SKIPPED — no ticket reference in _plan.md

Plan committed on <branch> (<short-sha>). No verify-feature handoff to print (verify-feature reads .claude/test-plans/<ticket>.yml which is keyed on ticket).

If the plan should have a ticket, edit `.claude/plans/<plan-name>/_plan.md` ## Related Issues and re-run verify-feature manually.
```

### Step 3b — HANDOFF

```
STATUS: PASS

╔══════════════════════════════════════════════════════════════╗
║  VERIFY-FEATURE HANDOFF                                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                                ║
║  Implementation committed:                                     ║
║    Branch:  <branch-name>                                      ║
║    HEAD:    <short-sha>  (<N> commits ahead of <base-branch>)  ║
║    Ticket:  #<NNN>                                             ║
║                                                                ║
║  To run verification:                                          ║
║                                                                ║
║    1. Open a NEW Claude Code thread (Ctrl-N or new terminal).  ║
║    2. In that thread, run:                                     ║
║                                                                ║
║         /verify-feature <NNN>                                  ║
║                                                                ║
║    3. When verify-feature finishes (all stories passing OR     ║
║       stops on a failure), come back to THIS thread and reply  ║
║       'verified' (or 'failed' with details).                   ║
║                                                                ║
║  Why a fresh thread:                                           ║
║    verify-feature owns its own TodoWrite list; running it in   ║
║    this thread would clobber the build thread's todos. The     ║
║    fresh-thread requirement is a skill convention, not a       ║
║    technical limit.                                            ║
║                                                                ║
╚══════════════════════════════════════════════════════════════╝
```

## When in doubt

- Don't try to invoke `/verify-feature` from inside this agent. The Skill tool can't cross threads, and the convention exists for a reason — TodoWrite collision is real.
- Don't include the test-plan YAML contents in the print — verify-feature will read them itself.
- Keep the box format. It's deliberately loud (the user has just watched a long orchestration finish; this needs to NOT get lost in the scrollback).
