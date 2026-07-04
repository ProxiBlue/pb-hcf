# Changelog

## [0.4.6] — 2026-07-04

Fable-era model targeting: review agents PROMOTED to fable, non-review paths held at sonnet/haiku. Assumes the operator runs the session on fable as the main orchestrator.

- **→ fable (7 review agents):** `gitnexus-reviewer`, `graphiti-reviewer`, `security-quorum`, `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor`, `pre-commit-adversarial-pass`. Deep judgment on impact analysis, historical conflict detection, security consensus, and last-chance adversarial pass — fable's reasoning depth pays back the per-call cost when it catches issues that opus would miss.
- **`skills/wire/SKILL.md`** — explicit `model: sonnet` added so `/pb-hcf:wire` no longer inherits the session model (previously would run on fable when the operator was in fable mode — wasted spend on a playbook installer).

**HCF-upstream review agents NOT touched:** `devils-advocate` and `standards-enforcer` remain at opus. Local override would drift on the next `plugin update hcf@hcf`. Recommend upstream PR: promote `devils-advocate` to fable (post-plan critique is exactly the review depth fable is worth); leave `standards-enforcer` at opus (structured rule check, doesn't need fable).

**Non-review tiers unchanged:** `tdd-worker` (sonnet — many invocations), 4 retrieval/templated agents (sonnet), 2 mechanical agents (haiku). Ceiling read of "fable for planning + review only" would have left the review agents at opus; assignment read (this release) makes them USE fable.

## [0.4.5] — 2026-07-02

Model tier optimization across the bundled agents — sonnet/haiku where reasoning depth is not the bottleneck, opus preserved everywhere judgment matters. Cuts per-plan token spend without weakening the review/security gates.

- **→ haiku (2):** `pre-flight-check` (yes/no artefact + branch + probe check, deterministic), `post-commit-verify-handoff` (prints an ASCII box with a slash command, purely mechanical).
- **→ sonnet (4):** `pre-plan-graphiti-recall`, `post-plan-manual-test-plan`, `pre-implementation-incident-recall`, `post-commit-build-summary` — structured retrieval + templated output; sonnet handles cleanly and `pre-implementation-incident-recall` fires per-task so the cost multiplier compounds.
- **opus kept (7):** `gitnexus-reviewer`, `graphiti-reviewer`, `security-quorum`, the 3 security specialists (`security-static-analyst` / `security-adversarial-tester` / `security-defensive-auditor`), `pre-commit-adversarial-pass`. All judgment-heavy — dropping tier here loses signal.

**Not touched (upstream HCF):** `devils-advocate` (opus, kept), `standards-enforcer` (opus, could drop to sonnet upstream), `tdd-worker` (sonnet, kept). HCF is `markshust/hcf`; local edits would drift on plugin update — recommend the standards-enforcer drop go via upstream PR instead.

**Not touched (skills):** `hcf:plan-create` is deliberately session-model bound — swap the session to fable before invoking, back to opus after (or use the `UserPromptSubmit` fable-reminder hook shipped in `~/claude-skills-central/hooks/` fleet-wide).

## [0.4.4] — 2026-07-01

**Requires:** HCF ≥ 2.0.0 (frontmatter-based hook enrollment; `.claude/pipeline.md` retired).

verify-feature contract wired into the post-plan agent — task files now carry the slug/test_name binding that tdd-worker honors at implementation time.

- **`agents/post-plan-manual-test-plan.md`** — new Step 4.5: after writing `.claude/test-plans/<ticket>.yml`, APPEND a `## Verify-feature contract` block to every per-task plan file (`.claude/plans/<plan-name>/NNN-*.md`) whose Requirements back a story with `spec_file` set + `manual_only: false`. Block carries the exact `story_slug` / `test_name` / `spec_file` triple plus the wrap instruction. Idempotent — re-running the agent replaces existing contract blocks rather than appending duplicates.
- **STATUS: PASS** output now reports a `Contracts:` line counting patched task files.
- **`README.md`** — new `## Requirements` section makes the HCF ≥ 2.0.0 hard dependency explicit (prior mentions were prose-only). Documents the install order: `hcf@hcf` → `/hcf:project-setup` → `pb-hcf@pb-hcf` → `/pb-hcf:wire --enable-all`.

**Why:** without this, `/proxiblue-skills:verify-feature` aborted at pre-flight because YAML story slugs never appeared as `// @story: <slug>` in any spec file — the tdd-worker had no signal at spec-authoring time that the contract existed. Pairs with `pb-hcf-playwright-tdd v0.4.0`, which teaches `testing.md` how to honor the block this agent writes.
