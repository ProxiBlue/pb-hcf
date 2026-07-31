# Task 002: Wire — bricklayer probe

**Status**: completed
**Depends on**: 001
**Retry count**: 0

## Description
Extend skills/wire/SKILL.md so wiring detects bricklayer (vendor/bin/bricklayer executable → capture CLI version) and records a bricklayer entry in wires.json playbooks[], installing templates/playbooks/bricklayer.md when the probe succeeds.

## Context
- **Wire-edit coordination:** skills/wire/SKILL.md is edited by several v0.5.0 tasks. This task edits ONLY (a) the "Per-playbook reachability probes" table and (b) the wires.json registry example — add the bricklayer row/entry. Use anchored Edits. Task 008 (bugsink probe) depends on this task and edits the SAME probe table next, so land the bricklayer row first.
- Related files: skills/wire/SKILL.md (probe + playbook install + wires.json registry sections)
- wires.json entry shape: see pps .claude/wires.json bricklayer entry (probe string, version detail, install note)
- Skip silently for non-Magento projects (no vendor/bin/bricklayer): record reachable=false with install hint, do NOT install playbook

## Requirements (Test Descriptions)
- [x] `it documents the bricklayer probe step (vendor/bin/bricklayer --version or list) in wire SKILL.md` — added `bricklayer.md` row to the "Per-playbook reachability probes" table (skills/wire/SKILL.md), landed before the bugsink row, per convention.
- [x] `it records reachable true with version detail in wires.json when binary present` — table cell documents `details.version` capture; wires.json registry example (step 5) now includes a `bricklayer` entry with `"details": { "version": "1.17.0" }`.
- [x] `it records reachable false with composer install hint when binary absent` — table cell documents `reachable: false` + `details.install` pointing at `composer require --dev inchoo/magento-bricklayer`, mirroring bugsink's `reachable: true`/`reachable: false` prose style.
- [x] `it installs templates/playbooks/bricklayer.md only when probe succeeds` — added an "Exception" paragraph under Actions step 1 (Install each playbook) gating the `.claude/bricklayer.md` copy on `reachable: true`; all other playbooks stay unconditional.

## Acceptance Criteria
- Wire SKILL.md instructions unambiguous for an executing agent; consistent with existing gitnexus/graphiti probe prose
