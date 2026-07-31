# Task 008: Wire — bugsink probe + release-tagging convention

**Status**: completed
**Depends on**: 002
**Retry count**: 0

## Description
Extend wire to probe the central Bugsink (env from ~/.pb-hcf/bugsink.env or container mount), record endpoint + project DSN presence in wires.json, and document the HCF_RELEASE tagging convention consumed by issue-sentinel and magento2-sentry.

## Context
- **Wire-edit coordination:** depends on task 002 which adds the bricklayer row to skills/wire/SKILL.md's "Per-playbook reachability probes" table + wires.json registry example. Re-read SKILL.md before editing, then add the bugsink row/entry to those same two sections via anchored Edits. Do not touch the enrollable-agent table (task 014 owns that) or the fence template (task 011).
- Probe: curl -s $BUGSINK_URL_CONTAINER/api/canonical/0/ with Bearer $BUGSINK_API_TOKEN (401/200 both prove reachability; connection-refused = unreachable); DSN presence = BUGSINK_DSN_<PROJECT> var exists
- wires.json entry: name bugsink, probe string, reachable, details {projectDsnVar, endpoint}
- Convention doc (new file docs/release-tagging.md): HCF_RELEASE=<plan-name>#<batch-n> exported by orchestration wrapper/env; magento2-sentry release config reads it; issue-sentinel filters on it; fallback when unset = git short SHA
- services/bugsink/README.md gains a "Wire integration" section pointing at the probe

## Requirements (Test Descriptions)
- [x] `it documents the bugsink probe using env-file credentials never hardcoded values`
- [x] `it records bugsink entry in wires.json with endpoint and DSN-var details`
- [x] `it treats HTTP 200 and 401 as reachable and connection failure as unreachable` (note: satisfied as part of requirement 1's probe-row edit — same table cell documents both the env-file sourcing and the 200/401/connection-refused rule; no separate edit needed)
- [x] `it ships docs/release-tagging.md defining HCF_RELEASE format and git-SHA fallback`

## Acceptance Criteria
- No secret values appear in any committed file

## Implementation Notes
- Task 002 (bricklayer row) had not landed yet at implementation time — no existing
  probe-table convention to follow from it, so the bugsink row was established cleanly per the
  task's own serialization note, added directly below the existing `graphiti.md` row.
- Added `bugsink` row to "Per-playbook reachability probes" table in `skills/wire/SKILL.md`
  (env-file-sourced `BUGSINK_URL_CONTAINER`/`BUGSINK_API_TOKEN`, 200-or-401-reachable rule,
  DSN-presence check via `BUGSINK_DSN_<PROJECT>`).
- Added `bugsink` entry to the `wires.json` registry example in SKILL.md step 5
  (`name`, `file: null` since it's not a playbook file, `probe`, `reachable`,
  `details.endpoint` + `details.projectDsnVar`).
- Did not touch the enrollable-agent table (task 014) or the fence template (task 011);
  the only overlapping in-flight edit encountered was task 006's constitution-install fenced
  block, which sits in a clearly delimited section and was left untouched.
- New file `docs/release-tagging.md` defines `HCF_RELEASE=<plan-name>#<batch-n>`, who sets it
  (orchestration wrapper), who consumes it (magento2-sentry `release` config, issue-sentinel
  filter), and the git-short-SHA fallback when unset.
- `services/bugsink/README.md` gained a "Wire integration" section pointing at the probe and
  cross-referencing `docs/release-tagging.md`.
- Secrets grep (`grep -rE '(ff15ea68|9c111c47)' --exclude-dir=.git .`) returns 0 hits across all
  edited/created deliverable files.
