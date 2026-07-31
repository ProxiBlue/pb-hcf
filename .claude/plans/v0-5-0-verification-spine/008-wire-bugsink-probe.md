# Task 008: Wire — bugsink probe + release-tagging convention

**Status**: pending
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
- [ ] `it documents the bugsink probe using env-file credentials never hardcoded values`
- [ ] `it records bugsink entry in wires.json with endpoint and DSN-var details`
- [ ] `it treats HTTP 200 and 401 as reachable and connection failure as unreachable`
- [ ] `it ships docs/release-tagging.md defining HCF_RELEASE format and git-SHA fallback`

## Acceptance Criteria
- No secret values appear in any committed file
