# Task 001: Bricklayer playbook template + gitnexus cross-ref

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
Seed the locally-authored pps bricklayer playbook as a portable pb-hcf template and add the bricklayer cross-reference (runtime-resolution arbitration) to the gitnexus playbook template, so wire runs never threaten hand-improved local copies again.

## Context
- Source of truth: /home/lucas/workspace/uptactics/pvcpipesupplies/.claude/bricklayer.md (genericize: strip pps-specific counts/paths where present; keep authority-scope, arbitration table, tier-1 tool list, reachability protocol, devils-advocate/tdd-worker/plan-create playbook sections)
- Target: templates/playbooks/bricklayer.md
- Also edit: templates/playbooks/gitnexus.md — add the "Bricklayer vs GitNexus — arbitration" pointer line present in pps's local copy
- Patterns: existing templates/playbooks/*.md declare "Authority scope" first

## Requirements (Test Descriptions)
- [ ] `it ships templates/playbooks/bricklayer.md with Authority scope section first`
- [ ] `it contains the gitnexus-vs-bricklayer arbitration table with trust-bricklayer-on-disagreement rule`
- [ ] `it contains the reachability check (composer require fallback) section`
- [ ] `it contains zero pps-specific strings (grep -ci 'pps\|pvcpipesupplies\|uptactics' = 0)`
- [ ] `it adds bricklayer cross-reference to templates/playbooks/gitnexus.md`

## Acceptance Criteria
- Both templates read standalone; wire can copy bricklayer.md to any Magento project unchanged
