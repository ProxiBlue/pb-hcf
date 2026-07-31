# Devil's Advocate Review: v0-5-0-verification-spine

Reviewed all 14 task files + _plan.md, cross-referenced against actual source
(agents/*.md, skills/wire/SKILL.md, scripts/discover-hooks.sh, plugin.json,
marketplace.json). Findings below; Critical + Important auto-applied to task
files and _plan.md.

## Critical (Must fix before building)

### C1 — New-agent frontmatter convention is INVERTED (tasks 003, 004, 005, 009)
The tasks require each new agent to "carry frontmatter phase X order Y mode Z".
Verified against source: pb-hcf agents ship **DORMANT** — `agents/<name>.md`
carries `name/description/model/tools` ONLY, never `phase/order/mode` (SKILL.md
line 106: "All 10 agents ship dormant … without phase"). The phase/order/mode
triple is stamped into a COPY at enrollment time by `wire --enable`, sourced
from the enrollable-agent table in `skills/wire/SKILL.md` step 4. Intended
order is documented in the agent BODY prose (e.g. graphiti-reviewer.md line 9
"You run at post-implementation, order 40").
`scripts/discover-hooks.sh` line 101 (`[[ -z "$phase" ]] && continue`) skips any
agent with no phase — so a source agent that "carries phase" would fire in EVERY
project that installs the plugin, violating dormant-by-default.
**Fix applied:** rewrote requirements in 003/004/005/009 to "ships DORMANT, no
phase/order/mode, documents intended enrollment in prose"; registration moved to
task 014 (see C4). Corrected _plan.md Discovery Notes.

### C2 — Order collision: mutation-tester 40 vs graphiti-reviewer 40 (task 005)
Task 005 assigns post-implementation order **40**. Verified order 40 is already
taken by graphiti-reviewer (agents/graphiti-reviewer.md line 9 + wire SKILL.md
line 98). Two agents at the same hook+order is ambiguous.
**Fix applied:** moved mutation-tester to **order 45** (between graphiti 40 and
standards 50, preserving the "before standards-enforcer" intent). Post-impl
line-up is now 30/40/45/50/70 — collision-free. Updated 005 + _plan.md.

### C3 — Constitution plan-dir copy is impossible at pre-plan (task 006)
Task 006 extends `pre-flight-check` (phase pre-plan, order 5) to "copy the
constitution into the plan dir as _constitution.md". Verified pre-flight-check.md
line 18 states "You do NOT have a plan name yet (Phase 3 creates it)" — there is
NO plan dir at pre-plan, so the copy cannot happen there.
**Fix applied:** split the responsibility — pre-flight-check only VERIFIES
existence + WARN (no copy); the plan-dir copy moves to
`pre-implementation-incident-recall` (phase pre-implementation, order 10), which
already resolves the in_progress plan name itself, holds the Edit tool, and
writes into the plan dir. Rewrote 006 description + requirements.

### C4 — Nothing registers the 4 new agents into wire (integration dead-end)
No task adds pre-mortem / pipeline-audit / mutation-tester / issue-sentinel to
the wire enrollable-agent table (SKILL.md step 4) or the `--enable-all` list
(line 213). Combined with C1 (agents ship dormant), the net effect is: the agents
exist as files but wire can never stamp them and discover-hooks never sees them —
they silently do nothing. Classic built-but-never-registered.
**Fix applied:** task 014 now explicitly (a) adds 4 rows to the enrollable table
with correct phase/order/mode, (b) bumps the "ships N agents" prose 10→14, (c)
adds all 4 to `--enable-all`, plus a requirement + acceptance test that
`wire --enable-all` + discover-hooks lists them collision-free.

## Important (Should fix before building)

### I1 — Wire SKILL.md edited by 5 tasks; shared probe section races (002, 006, 008, 011, 014)
002 + 008 both append to the SAME reachability-probe table and wires.json shape;
parallel workers would conflict on that hunk. 006 (install-mention), 011 (fence
pointer), 014 (enrollable table) touch disjoint sections.
**Fix applied:** added dep 008→002 to serialize the shared probe-table edit;
added explicit wire-edit coordination notes to 002/006/008/011 naming each task's
exclusive section + "re-read before anchored Edit". 014's registration runs last
(depends on all). Recorded the coordination contract in _plan.md Architecture Notes.

### I2 — pipeline-audit false-FAILs agents that leave no artefact (004, 005, 009)
Task 004 declares "absence of evidence = FAIL". But mutation-tester and
issue-sentinel (as originally written) emit inline PUSHBACK/PASS only — no
discoverable file — so pipeline-audit would FAIL agents that actually ran. Also
inline-only existing reviewers (gitnexus/graphiti/security/adversarial-pass)
write no plan-dir file at all.
**Fix applied:** 005 now writes `_mutation_tester.md`, 009 writes
`_issue_sentinel.md` (every run incl. PASS/degraded). 004 gains an explicit
agent→artefact map + a fallback (commit trailer/verdict log) for inline-only
reviewers, plus a zero-false-FAIL acceptance criterion.

### I3 — "custom namespace" filter source undefined (005, 011, 012)
Three tasks filter changed files "to custom namespaces from wires/config", but no
such config exists in wires.json. A worker would block asking where the list is.
**Fix applied:** defined one shared deterministic convention — changed `*.php`
under `app/code/`, excluding `generated/`, `vendor/`, fixtures — in _plan.md
Architecture Notes and in 005/011/012 directly. No config lookup needed.

### I4 — plugin.json / marketplace.json descriptions go stale (014)
Both embed "10 enrollable agents at 5 hook points"; 0.5.0 makes it 14 agents and
adds a NEW hook point (post-batch, via issue-sentinel). Task 014 only said "bump
version".
**Fix applied:** added a 014 requirement to update both description fields (agent
count + post-batch hook), and a note in 009 that post-batch is a newly-used hook.

## Minor (Nice to address — NOT applied)

- **M1 (task 005 cost ordering):** Infection is expensive; running it at order 45
  (before standards 50 / security 70) means a mutation PUSHBACK re-triggers the
  cheaper gates on retry. Could instead run last (order ~80) so it only fires once
  everything else passes. Kept at 45 to honor the task's stated intent; flagging
  the trade-off.
- **M2 (task 007 interview skill):** ensure it does NOT copy wire's
  `disable-model-invocation: true` — it must be model-invocable to trigger on
  vague asks. Acceptance already implies this; worth an explicit line.
- **M3 (task 004):** pipeline-audit at post-commit 90 runs only if orchestration
  reaches post-commit. A run that aborts mid-pipeline (e.g. security BLOCK) never
  reaches the auditor — so the auditor proves "everything that should have fired
  after a SUCCESSFUL run did", not "the run was complete". Worth stating that
  scope limit in the agent body.

## Questions for the Team

- **Q1:** Should mutation-tester run before standards (45, current) or after
  security (80) to minimize wasted Infection compute on retries? (See M1.)
- **Q2:** For inline-only reviewers (gitnexus/graphiti/security), is a
  commit-message trailer an acceptable evidence channel for pipeline-audit, or
  should those HCF-owned-adjacent agents also be nudged to drop a plan-dir marker?
  Current fix uses the commit-trailer fallback to avoid touching their contracts.
- **Q3:** The custom-code root is assumed `app/code/`. Any fleet project shipping
  custom modules under `vendor/<vendor>/` would be missed by the mutation/rector
  scope. Confirm app/code-only is acceptable for 0.5.0 (optional override noted).
