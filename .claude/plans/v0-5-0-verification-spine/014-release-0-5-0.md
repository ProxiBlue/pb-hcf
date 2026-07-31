# Task 014: Release 0.5.0

**Status**: pending
**Depends on**: 001, 002, 003, 004, 005, 006, 007, 008, 009, 010, 011, 012, 013
**Retry count**: 0

## Description
Cut the release: version bump, CHANGELOG entry covering all features, README feature index + --enable table update, final consistency sweep.

## Context
- Files: .claude-plugin/plugin.json + .claude-plugin/marketplace.json (0.4.9 → 0.5.0), CHANGELOG.md, README.md, **skills/wire/SKILL.md** (enrollable-agent registration — see below)
- **CRITICAL — register the 4 new agents into the wire enrollable machinery (without this they are dormant AND unreachable — wire can never stamp them):**
  1. Add 4 rows to skills/wire/SKILL.md step-4 enrollable-agent table (lines ~91-104): `pre-mortem` post-plan/20/single; `pipeline-audit` post-commit/90/single; `mutation-tester` post-implementation/**45**/single; `issue-sentinel` post-batch/30/single.
  2. Update the "pb-hcf ships N enrollable agents" prose (line ~89: 10→14) and "enroll all N" (line ~122).
  3. Add all 4 names to the `--enable-all` list (line ~213).
  4. Optionally add them to the "Recommended enrollment sets" table.
- **Update plugin.json + marketplace.json DESCRIPTIONS, not just the version:** current text says "10 enrollable agents at 5 hook points (pre-plan, post-plan, pre-implementation, post-implementation, pre-commit, post-commit)". After 0.5.0: 14 enrollable agents and a NEW hook point `post-batch` (issue-sentinel). Fix the counts + hook list in BOTH files' description fields.
- README: agents table gains pre-mortem/pipeline-audit/mutation-tester/issue-sentinel with phase/order (mutation-tester = 45, NOT 40); skills section gains interview/modernization-sweep; templates section gains rector/sentry/otel/constitution/bricklayer-playbook; wire --enable list updated
- Consistency sweep: every new agent source frontmatter parses (yaml) AND carries NO stray phase/order/mode (dormant convention — grep agents/*.md new files for `^phase:` = 0); every JSON/JSON5 valid; every shell script shellcheck-clean; no secret strings committed (grep for token/DSN literals); all new files referenced from README; wire enrollable table + --enable-all list contain all 4 new agents.

## Requirements (Test Descriptions)
- [ ] `it bumps version to 0.5.0 in plugin.json and marketplace.json`
- [ ] `it updates plugin.json and marketplace.json descriptions to 14 agents and adds the post-batch hook point`
- [ ] `it registers all 4 new agents in the wire SKILL.md enrollable table and --enable-all list with correct phase order mode`
- [ ] `it documents every 0.5.0 feature in CHANGELOG.md`
- [ ] `it lists all new agents skills and templates in README with phases and orders (mutation-tester order 45)`
- [ ] `it passes the consistency sweep: yaml frontmatter parses new agents carry no phase key json valid shellcheck clean and no-secrets greps`

## Acceptance Criteria
- Release commit leaves repo self-documenting; sync-plugin-versions.sh will pick up 0.5.0 on next fleet sync. `wire --enable-all` on a scratch project stamps all 14 agents and `scripts/discover-hooks.sh` lists the 4 new ones at their declared hooks/orders with no collisions.
