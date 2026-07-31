# Task 012: modernization-sweep skill

**Status**: pending
**Depends on**: 010
**Retry count**: 0

## Description
New skill skills/modernization-sweep/SKILL.md: apply-mode rector for EXISTING code. One ruleset x one module per run, own feature branch, full test + reviewer chain before merge. Designed as ralph-loop-friendly grind work.

## Context
- **Module/namespace scope:** modules live under `app/code/<Vendor>/<Module>/` (the custom-code root; same definition tasks 005/011 use). "pick a module" = pick one `app/code/<Vendor>/<Module>` dir. Never touch `vendor/` or `generated/`.
- Flow: pick module (arg or smallest-first) → pick next ruleset from ordered ladder (UP_TO_PHP_83 → code-quality → type-declaration → dead-code) → branch modernize/<module>-<set> → rector process (apply) → run module unit tests + rector-check idempotency (second dry-run = empty) → commit → hand to standard review chain (never self-merge) → record progress in .claude/modernization-state.json
- Guardrails: refuse on dirty tree; refuse on protected branch; one module one set per invocation (bounded blast radius); state file tracks module x set completion matrix
- Ralph note in SKILL.md: safe completion promise = state matrix full

## Requirements (Test Descriptions)
- [ ] `it processes exactly one module and one ruleset per invocation`
- [ ] `it creates a dedicated modernize branch and refuses dirty or protected-branch starts`
- [ ] `it verifies idempotency with a post-apply empty dry-run`
- [ ] `it runs the module's unit tests before committing`
- [ ] `it tracks completion in modernization-state.json and never self-merges`

## Acceptance Criteria
- Skill loops cleanly under ralph (bounded, stateful, reviewer-gated)
