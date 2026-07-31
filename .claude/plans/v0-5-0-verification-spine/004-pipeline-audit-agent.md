# Task 004: pipeline-audit agent

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
New enrollable agent agents/pipeline-audit.md: after orchestration completes, proves which enrolled pipeline phases actually fired vs silently skipped. Mechanizes the hcf-build-integration-gaps lesson (built-but-never-fired integrations).

## Context
- **Enrollment convention (VERIFIED):** source ships DORMANT — no `phase/order/mode` in frontmatter. Body prose documents "You run at post-commit, order 90, mode single — the tail of the pipeline; v2 has no literal post-orchestration hook, so post-commit tail IS the last observable point. After post-commit-build-summary (order 20)." Task 014 registers the phase/order/mode triple in the wire enrollable table.
- **Evidence-artefact map (must be explicit + maintainable in the agent body).** Each enrolled agent is evidenced by a KNOWN artefact:
  - devils-advocate → `_devils_advocate.md`; pre-mortem → `_pre_mortem.md`; post-plan-manual-test-plan → `.claude/test-plans/<ticket>.yml`; mutation-tester → `_mutation_tester.md`; issue-sentinel → `_issue_sentinel.md`; pre-implementation-incident-recall → `## Prior incidents` block prepended to task files.
  - Inline-only reviewers that write NO plan-dir file (gitnexus-reviewer, graphiti-reviewer, security-quorum, pre-commit-adversarial-pass, standards-enforcer): evidenced via commit-message trailer or the orchestrator's per-hook verdict log. The agent body MUST state this fallback so an inline-only reviewer that DID fire is not false-FAILed.
  - Derive the EXPECTED list from `.claude/wires.json` `enrollments[]` (not hardcoded names). For each, look up its artefact via the map above.
- Output: table enrolled-agent → evidence-found(path) | NO-EVIDENCE; verdict PASS (all evidenced) / FAIL (any silent skip)
- Reporting: post via chatroom MCP thread to host when available (subject "pipeline-audit <plan> <verdict>"), else write _pipeline_audit.md in plan dir; never hard-fail when chatroom absent

## Requirements (Test Descriptions)
- [ ] `it ships DORMANT with no phase/order/mode in source frontmatter and documents intended post-commit order-90 single enrollment in the body prose`
- [ ] `it derives the expected-agent list from wires.json enrollments not from hardcoded names`
- [ ] `it maps each expected agent to a concrete evidence artefact path via a documented agent-to-artefact map`
- [ ] `it evidences inline-only reviewers (no plan-dir file) via commit trailer/verdict log rather than false-FAILing them`
- [ ] `it returns FAIL when any enrolled agent lacks evidence`
- [ ] `it degrades to _pipeline_audit.md file when chatroom MCP is unavailable`

## Acceptance Criteria
- Zero false-PASS: absence of evidence = FAIL, stated in instructions verbatim. Zero false-FAIL: an agent that fired but writes no plan-dir file is evidenced via its documented fallback, not reported as a silent skip.
