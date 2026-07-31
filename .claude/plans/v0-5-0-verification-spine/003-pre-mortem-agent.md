# Task 003: pre-mortem agent

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
New enrollable agent agents/pre-mortem.md: prospective failure analysis of a freshly created plan. Distinct lens from devils-advocate (gap-finding): assumes the plan ALREADY FAILED in production and works backwards to the most plausible causes, then verifies each against plan tasks.

## Context
- **Enrollment convention (VERIFIED):** source file ships DORMANT — frontmatter carries `name/description/tools` only (model omitted = inherit), NO `phase/order/mode`. Intended enrollment is documented in the BODY prose: "You run at post-plan, order 20 — AFTER devils-advocate (HCF default, order 10) and BEFORE post-plan-manual-test-plan (order 50)." Copy the shape of an existing dormant agent (agents/post-plan-manual-test-plan.md) — note it too has no phase key in source. The `phase: post-plan / order: 20 / mode: single` triple is registered in the wire enrollable table by task 014, which is what lets `wire --enable=pre-mortem` stamp it.
- Ordering rationale: order 20 sits between devils-advocate (10) and manual-test-plan (50) so pre-mortem's auto-applied task edits land BEFORE manual-test-plan mines requirements.
- Patterns: agents/post-plan-manual-test-plan.md for post-plan agent shape; devils-advocate output conventions (_devils_advocate.md) — pre-mortem writes _pre_mortem.md into the plan dir (this file is ALSO pipeline-audit's evidence that pre-mortem fired).
- Output: ranked failure scenarios (likelihood × blast radius), each mapped to CONFIRMED-COVERED (cites task requirement) or UNCOVERED (proposes concrete new requirement/task edit). Auto-apply Critical items to task files, list the rest for the user — mirror devils-advocate's auto-apply convention.

## Requirements (Test Descriptions)
- [ ] `it ships DORMANT with no phase/order/mode in source frontmatter and documents intended post-plan order-20 single enrollment in the body prose`
- [ ] `it instructs assume-failure-then-work-backwards method with likelihood and blast-radius ranking`
- [ ] `it requires every scenario mapped to a covering task requirement or an UNCOVERED proposal`
- [ ] `it writes _pre_mortem.md to the plan directory and auto-applies Critical fixes to task files`
- [ ] `it explicitly differentiates its lens from devils-advocate to avoid duplicate findings`

## Acceptance Criteria
- After task 014 registers it and `wire --enable=pre-mortem` stamps the phase, `scripts/discover-hooks.sh --hook=post-plan` lists it at order 20, after devils-advocate/order 10 and before manual-test-plan/order 50.
