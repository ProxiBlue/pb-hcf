# Task 005: mutation-tester agent + infection template

**Status**: completed
**Depends on**: none
**Retry count**: 0

## Description
New enrollable agent agents/mutation-tester.md + templates/infection/infection.json5.dist: run Infection mutation testing on the plan's changed PHP files only, gate on min-MSI, PUSHBACK listing surviving mutants so tdd-workers strengthen assertions. Tests-that-test-the-tests — counters coverage-gaming.

## Context
- **Enrollment convention (VERIFIED):** source ships DORMANT — no `phase/order/mode`. Body prose documents "You run at post-implementation, order **45** — AFTER graphiti-reviewer (40) and BEFORE standards-enforcer (50)." Task 014 registers the triple in the wire enrollable table.
- **ORDER: 45, NOT 40.** Order 40 is already taken by graphiti-reviewer (verified: agents/graphiti-reviewer.md line 9 + wire SKILL.md line 98). Post-implementation line-up after this change: codegraph 30, graphiti 40, mutation-tester 45, standards 50, security-quorum 70 — no collision.
- **Changed-files scope (shared convention):** git-changed `*.php` under `app/code/`, excluding `generated/`, `vendor/`, and test fixtures. `git diff --name-only <plan-start-ref>..HEAD -- 'app/code/**/*.php'`; use Infection --filter on those paths. (Same scoping definition used by tasks 011 and 012 — do NOT invent a separate "custom namespace" config source; app/code/ IS the custom-code root.)
- Template: templates/infection/infection.json5.dist (source dirs placeholder app/code/<Vendor>, timeout, min-msi 60 + min-covered-msi 75 as documented defaults, text+summary loggers) + README.md (composer require --dev infection/infection; caveats: runtime cost, run once per plan not per batch)
- **Evidence artefact:** write a `_mutation_tester.md` verdict file into the plan dir (MSI achieved, surviving-mutant list or PASS/PASS-with-note) so pipeline-audit (task 004) can prove this agent fired. Inline PUSHBACK alone is not discoverable.
- Graceful degrade: infection binary absent → PASS-with-note instructing composer install; never block on missing tool, record the gap loudly (still write _mutation_tester.md noting the skip).

## Requirements (Test Descriptions)
- [x] `it ships DORMANT with no phase/order/mode in source frontmatter and documents intended post-implementation order-45 single enrollment in the body prose`
- [x] `it scopes mutation run to changed app/code php files only excluding generated vendor and fixtures`
- [x] `it gates on min-MSI threshold and returns PUSHBACK listing each surviving mutant with file line and mutator`
- [x] `it writes _mutation_tester.md verdict to the plan dir on every run including PASS and degraded-skip`
- [x] `it instructs PASS-with-note when infection is not installed`
- [x] `it ships valid infection.json5.dist parseable as JSON5 with placeholder source dirs`

## Acceptance Criteria
- PUSHBACK format consumable by tdd-worker retry loop (file:line + expected assertion improvement). Order 45 confirmed collision-free via `scripts/discover-hooks.sh --hook=post-implementation` once enrolled.

## Implementation Notes
- `agents/mutation-tester.md`: dormant frontmatter (name/description/tools only); body documents 6-step Process (scope → degrade-check → run → gate → verdict → write artefact), Side effects, and When in doubt sections mirroring `codegraph-reviewer.md`'s canon shape.
- `templates/infection/infection.json5.dist`: JSON5 with full-line `//` comments (no inline trailing comments, so the strip-then-`json.loads` grading method works); placeholder `app/code/<Vendor>` source dir; `minMsi: 60` / `minCoveredMsi: 75` documented defaults; `logs.json` path is what the agent parses for file:line + mutator PUSHBACK entries.
- `templates/infection/README.md`: composer require --dev infection/infection, --filter scoping example, runtime-cost caveat, once-per-plan-not-per-batch, graceful-degrade note.
- Registration into wire's enrollable-agent table is explicitly task 014's job, not this task's — left untouched here per the task's own Context note.
