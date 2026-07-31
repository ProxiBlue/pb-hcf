# Task 014: Release 0.5.0

**Status**: completed
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
- [x] `it bumps version to 0.5.0 in plugin.json and marketplace.json`
- [x] `it updates plugin.json and marketplace.json descriptions to 14 agents and adds the post-batch hook point`
- [x] `it registers all 4 new agents in the wire SKILL.md enrollable table and --enable-all list with correct phase order mode`
- [x] `it documents every 0.5.0 feature in CHANGELOG.md`
- [x] `it lists all new agents skills and templates in README with phases and orders (mutation-tester order 45)`
- [x] `it passes the consistency sweep: yaml frontmatter parses new agents carry no phase key json valid shellcheck clean and no-secrets greps`

## Implementation Notes

- Bumped `version` and rewrote the description field in both `.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json`: 10→14 enrollable agents, 5→7 hook points, added `post-batch`
  to the hook list, folded the 4 new agents + interview/modernization-sweep skills into the prose.
- `skills/wire/SKILL.md` step-4 enrollable table gained 4 rows (`pre-mortem` post-plan/20/single,
  `issue-sentinel` post-batch/30/single, `mutation-tester` post-implementation/45/single,
  `pipeline-audit` post-commit/90/single), the "ships N enrollable agents" prose and "enroll all N"
  line bumped to 14, the `--enable-all` shorthand list expanded to all 14 names, and a
  "verification spine only" row added to the recommended-enrollment-sets table.
- README: intro paragraph, Skills table (+`/pb-hcf:interview`, +`/pb-hcf:modernization-sweep`),
  Enrollable agents table (+4 rows with correct phase/order — mutation-tester at 45, not 40),
  Playbook templates table (+`bricklayer.md`), new "Other templates" table (constitution, rector,
  infection, sentry, otel, release-tagging, rector-check.sh), Default-enrollment-knobs table
  reordered to show the 4 new agents' position relative to the existing pipeline, and a new
  v0.5.0 row in the `## Status` table (with a `v0.4.4–v0.4.9` roll-up row added first since the
  table had been left stale at v0.4.3 pre-existing that gap, closed here for release hygiene).
- CHANGELOG.md: full `[0.5.0]` entry (Added/Changed) covering all 13 preceding tasks' deliverables.
- Consistency-sweep fix in scope: `scripts/discover-hooks.sh` line 108 used `ls "$TARGET"/*.md |
  sort` (shellcheck SC2012) — pre-existing from v0.4.2, not part of tasks 001-013, but caught by
  this task's mandatory `shellcheck scripts/*.sh hooks/*.sh` sweep gate. Fixed to
  `find "$TARGET" -maxdepth 1 -name '*.md' | sort` (same behaviour, clean under shellcheck).
  shellcheck itself was not present in the sandbox; installed the static `shellcheck-stable`
  binary (v0.11.0) from GitHub releases into the scratchpad to run the sweep.
- Secrets-grep sweep command (`grep -rE '(ff15ea68|9c111c47)' --exclude-dir=.git .`) returns 3
  hits — all are literal mentions of the grep pattern itself inside `.claude/testing.md` and two
  `.claude/plans/.../00{8,9}-*.md` task docs describing the test, not actual secret values. No
  real credential is committed anywhere in the tree.

## Acceptance Criteria
- Release commit leaves repo self-documenting; sync-plugin-versions.sh will pick up 0.5.0 on next fleet sync. `wire --enable-all` on a scratch project stamps all 14 agents and `scripts/discover-hooks.sh` lists the 4 new ones at their declared hooks/orders with no collisions.
