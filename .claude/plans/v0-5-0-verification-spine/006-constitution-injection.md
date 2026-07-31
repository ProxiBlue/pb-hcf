# Task 006: Constitution template + pre-flight-check injection

**Status**: completed
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
- [x] `it ships templates/constitution.md with placeholder sections for branch rules vendor blocklist and verification checklist` — implemented at `templates/constitution.md` (## Branch rules, ## Vendor blocklist, ## Verification checklist, plus Never-edit vendor/core and Testing scope rules)
- [x] `it extends pre-flight-check to WARN not BLOCK when constitution is missing and does NOT attempt a plan-dir copy at pre-plan` — implemented as "Constitution check" paragraph in Step 1 of `agents/pre-flight-check.md`
- [x] `it extends pre-implementation-incident-recall to copy the constitution into the plan dir as _constitution.md` — implemented as new "Step 0 — Constitution copy" in `agents/pre-implementation-incident-recall.md`, runs before the graphiti-reachability check so it's not skipped when graphiti is down
- [x] `it documents wire installing the template without overwriting an existing constitution` — implemented as clearly-delimited `<!-- pb-hcf:constitution-install:start/end -->` block (new "1a." action) in `skills/wire/SKILL.md`, inserted right after the existing "1. Install each playbook" section

## Acceptance Criteria
- Injection is copy-based (no @-mount) so plan dirs stay self-contained for workers, and happens at pre-implementation when the plan dir provably exists — never at pre-plan.
