# Task 012: modernization-sweep skill

**Status**: completed
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
- [x] `it processes exactly one module and one ruleset per invocation`
- [x] `it creates a dedicated modernize branch and refuses dirty or protected-branch starts`
- [x] `it verifies idempotency with a post-apply empty dry-run`
- [x] `it runs the module's unit tests before committing`
- [x] `it tracks completion in modernization-state.json and never self-merges`

## Acceptance Criteria
- Skill loops cleanly under ralph (bounded, stateful, reviewer-gated)

## Implementation Notes
- `skills/modernization-sweep/SKILL.md` written with frontmatter (`name: modernization-sweep`,
  trigger-phrase description covering "modernize module", "rector sweep", "upgrade php conventions")
  plus body sections: Bounded blast radius, Ordered ruleset ladder (mirrors
  `templates/rector/rector.php.dist`), Guardrails (dirty-tree refusal via `git status --porcelain`,
  protected-branch refusal for live/uat/main/master per `agents/pre-flight-check.md`'s convention,
  dedicated `modernize/<module>-<set>` branch creation), Process (apply → post-apply empty dry-run
  idempotency check → module unit tests before commit → commit → hand off to standard review chain,
  never self-merge → record progress), `.claude/modernization-state.json` module × ruleset completion
  matrix schema (portable module discovery via `app/code/<Vendor>/<Module>/` glob, no hardcoded module
  names), and a ralph-loop note stating the only safe completion promise is a full state matrix.
- Requirement 3 ("idempotency") and requirement 4 ("unit tests before committing") grep-passed
  immediately off the frontmatter description alone (over-implementation carried over from
  requirement 1's description draft) — noted per TDD discipline, then given full substantive body
  sections anyway so the skill is actually usable, not just grep-satisfying.
- Verified: YAML frontmatter parses (`python3 -c "import yaml..."`), all 8 required-phrase greps pass,
  secrets grep returns 0 hits (per `.claude/testing.md`).
