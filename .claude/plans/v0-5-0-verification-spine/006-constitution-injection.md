# Task 006: Constitution template + pre-flight-check injection

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
Ship templates/constitution.md (immutable project invariants); have pre-flight-check VERIFY it exists (WARN if missing), and have pre-implementation-incident-recall COPY it into the plan directory as _constitution.md, so every tdd-worker and reviewer carries the invariants without re-derivation.

## Context
- Template content (placeholder-driven, per-project fill-in): never-edit-vendor/core, branch + squash-merge rules, deploy commit format, upgrade-verification checklist reference, vendor blocklist pointer (graphiti query instruction), testing scope rules
- **TIMING FIX (VERIFIED):** pre-flight-check runs at `pre-plan` and its body states "You do NOT have a plan name yet (Phase 3 creates it)" — so it CANNOT copy into the plan dir (no plan dir exists yet). Split the responsibility:
  - **agents/pre-flight-check.md** (pre-plan): add a check that `.claude/constitution.md` exists → STATUS WARN when missing (NOT BLOCK; adoption is gradual). NO plan-dir copy here.
  - **agents/pre-implementation-incident-recall.md** (pre-implementation, order 10): it already resolves the in_progress plan name itself and has the `Edit` tool + writes into the plan dir per task. Add a step: if `.claude/constitution.md` exists, copy it once into the plan dir as `_constitution.md` before/alongside the per-task incident prepend. This is the point where the plan dir is guaranteed to exist.
- Wire: install templates/constitution.md to .claude/constitution.md when absent (mention in SKILL.md — this is a wire SKILL.md edit; touch ONLY the actions/install section, use an anchored Edit, re-read the file first since tasks 002/008 may have edited other sections). Do NOT overwrite an existing constitution.

## Requirements (Test Descriptions)
- [ ] `it ships templates/constitution.md with placeholder sections for branch rules vendor blocklist and verification checklist`
- [ ] `it extends pre-flight-check to WARN not BLOCK when constitution is missing and does NOT attempt a plan-dir copy at pre-plan`
- [ ] `it extends pre-implementation-incident-recall to copy the constitution into the plan dir as _constitution.md`
- [ ] `it documents wire installing the template without overwriting an existing constitution`

## Acceptance Criteria
- Injection is copy-based (no @-mount) so plan dirs stay self-contained for workers, and happens at pre-implementation when the plan dir provably exists — never at pre-plan.
