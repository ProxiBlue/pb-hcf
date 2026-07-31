# Changelog

## [Unreleased]

### Changed (post-0.5.0, unreleased)

- **Code-graph backend swap: the legacy licensed code-graph tool → pb-codegraph (native).** The
  fleet code graph now runs on pb-codegraph (https://github.com/ProxiBlue/pb-codegraph). All
  references to the previous licensed tool are purged from this repo:
  - MCP tool names: `mcp__<legacy-server>__{list_repos,find_symbol,impact,context,query}` →
    `mcp__pb-codegraph__*` (same five tool names, new server id `pb-codegraph`) across every
    agent's `tools:` frontmatter and prose.
  - Agent rename: the code-graph reviewer (formerly named after the legacy tool) →
    **`codegraph-reviewer`** (frontmatter `name:`, title, all cross-references in wire SKILL,
    README, pipeline-audit, mutation-tester, post-commit-build-summary, security playbook,
    graphiti-reviewer). Enrollment semantics unchanged (`post-implementation`, order 30, mode
    single).
  - Playbook rename: the code-graph playbook template (formerly named after the legacy tool) →
    **`templates/playbooks/codegraph.md`** (installs as `.claude/codegraph.md`); authority scope
    and the bricklayer arbitration cross-reference preserved.
  - Liveness probe: the old `curl :4747` HTTP check → **`pb-codegraph health --registry
    "${PB_CODEGRAPH_REGISTRY:-.ddev/pb-codegraph/registry.json}"`** exit-0 (`status: "green"`)
    check, in `pre-flight-check`, `codegraph-reviewer`, the security agents, and wire's probe
    table / `wires.json` example.
  - NOTICE / plugin.json / marketplace.json updated to reference pb-codegraph.
  - Historical entries below were reworded in place to the new names (rename-only; no
    behavioral history rewritten).

## [0.5.0] — 2026-07-31

**Verification spine.** Four new enrollable agents, a new `post-batch` hook point, and a batch of
supporting templates/skills/docs that close plan-quality, test-quality, runtime-error, and
pipeline-proof gaps left open by v0.4.x. Wire's enrollable-agent table grows from 10 to **14
agents at 7 hook points** (`pre-plan`, `post-plan`, `pre-implementation`, `post-batch`,
`post-implementation`, `pre-commit`, `post-commit`); `--enable-all` now enrolls all 14.

### Added

- **`pre-mortem` agent** (`post-plan`, order 20, single) — prospective failure analysis. Assumes
  the freshly created plan already failed in production, works backwards to the most plausible
  causes ranked by likelihood × blast radius, then checks each against the plan's task
  requirements as CONFIRMED-COVERED or UNCOVERED. Distinct lens from `devils-advocate`
  (gap-finding forward from the plan vs failure-backwards from an assumed incident); runs after
  it (order 10) and before `post-plan-manual-test-plan` (order 50).
- **`mutation-tester` agent** (`post-implementation`, order **45**, single) + `templates/infection/`
  (`infection.json5.dist` + README) — tests-that-test-the-tests. Runs Infection mutation testing
  scoped to the plan's changed PHP files only (`app/code/**`, excluding generated/vendor/fixtures),
  gates on a min-MSI threshold, and returns PASS or PUSHBACK listing every surviving mutant
  (file:line + mutator) so tdd-workers strengthen assertions instead of gaming coverage. Runs once
  per plan, after `graphiti-reviewer` (40) and before `standards-enforcer` (50).
- **`issue-sentinel` agent** (**new `post-batch` hook point**, order 30, single) +
  `templates/sentry/README.md` — runtime-error gate. After each batch, queries the central
  Bugsink error tracker for issues `first_seen` since the batch started (project +
  `HCF_RELEASE`-filtered), triages via bricklayer `diagnose-error` where wired, and returns PASS
  or structured PUSHBACK with `friendly_id` + stacktrace excerpt + suspected file:line. Falls
  back to a thin `var/report` + cron-stderr scan when Bugsink is unreachable. Writes
  `_issue_sentinel.md` to the plan dir every batch — first agent to use pb-hcf's `post-batch`
  hook point. `templates/sentry/README.md` documents the per-project `justbetter/magento2-sentry`
  install that feeds Bugsink.
- **`pipeline-audit` agent** (`post-commit`, order 90, single) — proves which enrolled pipeline
  phases actually fired vs silently skipped this run. Mechanizes the
  hcf-build-integration-gaps lesson (built-but-never-fired integrations). Derives the
  expected-agent list from `.claude/wires.json` enrollments, maps each to a documented evidence
  artefact, and posts a PASS/FAIL verdict via chatroom MCP (else writes `_pipeline_audit.md` in
  the plan dir). Runs last, tail of `post-commit`, so any artefact another agent could have
  written already exists on disk before the audit runs.
- **`templates/playbooks/bricklayer.md`** — runtime-resolved-truth playbook for the
  `inchoo/magento-bricklayer` MCP (DI preferences, merged plugin chains, live EAV, actual DB
  schema, error triage). Probe-gated install: `/pb-hcf:wire` only copies it when
  `vendor/bin/bricklayer` is detected on the target project; unreachable projects get a
  `reachable: false` + install-hint entry in `wires.json` instead. `codegraph.md` gains a
  cross-reference: on a resolution disagreement between the static graph and the live app, trust
  bricklayer.
- **`templates/constitution.md`** — immutable project-invariants template. `/pb-hcf:wire` installs
  it once to `.claude/constitution.md` (install-without-overwrite — an existing file is never
  touched). `pre-flight-check` WARNs (does not BLOCK) when it's missing. `pre-implementation-incident-recall`
  copies it, verbatim and idempotently, into each plan dir as `_constitution.md` once the plan dir
  exists, so every tdd-worker and reviewer carries the invariants without re-deriving them.
- **`/pb-hcf:interview` skill** — pre-plan clarity-scored scope builder. Interviews the user one
  question at a time (Harper Reed pattern), scores the emerging spec across Goal / Constraints /
  Success Criteria / Context (0–5 each), and refuses handoff to `/hcf:plan-create` below threshold
  16/20. Auto-triggers on vague build asks ("flesh out scope", "spec this out", …) — no explicit
  invocation required.
- **`/pb-hcf:modernization-sweep` skill** — apply-mode rector for *existing* custom Magento code.
  Exactly one `app/code/<Vendor>/<Module>` × one ruleset per invocation off the ordered ladder
  (`UP_TO_PHP_83` → code-quality → type-declaration → dead-code), its own
  `modernize/<module>-<set>` branch, dirty-tree + protected-branch refusals, a post-apply
  idempotency dry-run, the module's unit tests, then hand-off to the standard review chain. Never
  merges itself. Designed as bounded, ralph-loop-friendly grind work; tracks progress in
  `.claude/modernization-state.json`.
- **`templates/rector/`** (`rector.php.dist` + README) — deterministic PHP 8.3 modernization
  convention for Magento custom code: code-quality + type-declaration + dead-code rector sets,
  custom-namespace `withPaths()` placeholder, and a `withSkip()` list encoding known
  Magento-plugin-breaking rules (readonly classes/properties, unused-constructor/plugin-param
  removal, dynamic-property completion) with a one-line WHY each.
- **`scripts/rector-check.sh`** — deterministic dry-run gate: rector against changed
  `app/code/**/*.php` files only, non-empty proposed-transform diff = exit 1. Documented for
  `post-batch` / `pre-commit` use.
- **`templates/otel/otel.env.dist` + `services/otel/README.md`** — Claude Code OTLP telemetry
  for the fleet: client-side env template (`CLAUDE_CODE_ENABLE_TELEMETRY`,
  `OTEL_METRICS_EXPORTER`, `OTEL_EXPORTER_OTLP_ENDPOINT`, per-project resource attributes) and a
  collector-options doc (SigNoz vs Langfuse vs plain otel-collector→file, mirror-of-bugsink
  singleton pattern, what metrics matter). Docs + env only for 0.5.0 — no collector deployment
  ships yet.
- **`docs/release-tagging.md`** — the `HCF_RELEASE=<plan-name>#<batch-n>` convention that ties
  Bugsink events and `magento2-sentry` releases to a specific plan/batch, consumed by
  `issue-sentinel`'s `first_seen`-since-batch-start query.
- **Wire — bugsink probe.** `/pb-hcf:wire` (and `--reprobe`) now probes the central Bugsink
  instance, sourcing credentials from `~/.pb-hcf/bugsink.env` (never hardcoded), treating HTTP
  `200` **or** `401` as reachable (either proves the service answered), and recording a separate
  `BUGSINK_DSN_<PROJECT>`-presence boolean in `wires.json`.
- **Wire — bricklayer probe.** `/pb-hcf:wire` detects `vendor/bin/bricklayer`, captures its CLI
  version, and records the result (or an install hint) in `wires.json`'s `playbooks[]`.

### Changed

- **`skills/wire/SKILL.md`** — enrollable-agent table grows from 10 to 14 rows (adds
  `pre-mortem`, `issue-sentinel`, `mutation-tester`, `pipeline-audit` at their intended
  `phase`/`order`/`mode`); "ships N enrollable agents" prose and `--enable-all` shorthand list
  updated to all 14 names; new "verification spine only" row added to the recommended
  enrollment-sets table.
- **`agents/pre-flight-check.md`** — new constitution check: WARN (not BLOCK) when
  `.claude/constitution.md` is missing, since adoption is gradual and this hook runs before a
  plan dir exists to copy into.
- **`agents/pre-implementation-incident-recall.md`** — new Step 0: copies
  `.claude/constitution.md` into the plan dir as `_constitution.md` once the plan dir provably
  exists, independent of graphiti reachability, idempotent on re-run.
- **`agents/pre-commit-adversarial-pass.md`** — new Step 4 (renumbering the verdict-build step to
  5): judges `scripts/rector-check.sh`'s contested transforms — public method signature changes,
  dead-code removal, and constructor changes near plugin/observer/`di.xml` wiring rector's own
  skip-list doesn't cover — citing file:line + the specific Magento mechanism at risk.
- **`templates/playbooks/codegraph.md`** — adds a defer-to-bricklayer line for "what actually
  resolves at runtime" questions, since pb-codegraph's static snapshot can't see env-specific module
  enablement.
- **`services/bugsink/README.md`** — documents the wire integration (probe semantics, DSN-presence
  check) and points at `docs/release-tagging.md` for the `HCF_RELEASE` convention.
- **`.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`** — version 0.4.9 → 0.5.0;
  descriptions updated from "10 enrollable agents at 5 hook points" to "14 enrollable agents at
  7 hook points", with `post-batch` added to the hook list and the new agents folded into the
  capability summary.
- **`README.md`** — agents table gains `pre-mortem` / `issue-sentinel` / `mutation-tester` /
  `pipeline-audit` with phase/order (mutation-tester at order 45, distinct from the reviewer pair
  at 30/40); skills table gains `/pb-hcf:interview` and `/pb-hcf:modernization-sweep`; playbook
  table gains `bricklayer.md`; new "Other templates" table covers constitution/rector/infection/
  sentry/otel/release-tagging/rector-check.sh; default-enrollment-knobs table reordered to show
  where each new agent sits relative to the existing pipeline; Status table gains a v0.5.0 row.

## [0.4.9] — 2026-07-05

Third revision on the reviewer-tier question. Reverts v0.4.8's fable pins — reviewers inherit again — but this time the rule is refined to reflect the intent: **operator-controlled review tier via `/model` swap for outcome A/B testing**.

- **→ inherit (was fable in v0.4.8):** `codegraph-reviewer`, `graphiti-reviewer`, `security-quorum`, `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor`, `pre-commit-adversarial-pass`. Same set as v0.4.7 — `model:` line removed from frontmatter.
- **HCF-upstream (local drift):** `hcf/agents/devils-advocate.md` also unpinned (was fable in v0.4.8).

**Intent:** run session=fable for a high-stakes plan → reviews use fable. Drop session=opus for cost-sensitive iteration → reviews use opus. Drop session=sonnet to A/B test outcomes at a lower tier without any file edits. Reviewers dial with the session.

**Known caveat:** if Claude Code's Task-subagent model resolution follows immediate-caller precedence rather than top-level session (semantics not publicly documented), unpinned reviewers dispatched from `plan-orchestrate` (which has explicit `model: sonnet`) may inherit sonnet, silently downgrading review depth. Two mitigations documented in `~/claude-skills-central/rules/model-tiering.md`: (a) unpin `plan-orchestrate` too (local drift on HCF upstream), or (b) empirically verify per plan via transcript metadata and re-pin if the downgrade materialises.

## [0.4.8] — 2026-07-05

Re-pin review agents to `model: fable`. Rule refined: reviewers are non-negotiable, pin explicitly to the ceiling — do NOT rely on session-inheritance since harness precedence for Task-dispatched subagents (parent-caller vs top-level session) is not guaranteed to bubble up.

- **→ fable (7 review agents):** `codegraph-reviewer`, `graphiti-reviewer`, `security-quorum`, `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor`, `pre-commit-adversarial-pass`. Same set as v0.4.6; reverts the v0.4.7 unpinning.
- **`~/claude-skills-central/rules/model-tiering.md`** updated: "inherit for verify/security/final-judge" clause removed; replaced with "**fable (or strongest available)**: verify / security / final-judge / review-panel stages. Pin explicitly — do NOT rely on inheritance from the calling skill or session." Reviewers get their own row; `inherit` is now reserved for orchestration + hard-design skills.
- **HCF-upstream (local drift):** `hcf/agents/devils-advocate.md` also re-pinned to `model: fable`. Will re-drift on `plugin update hcf@hcf`.

**Why the flip-flop:** v0.4.7 assumed session-model inheritance (semantics A: sub-agents fall back to top-level session tier). Operator called out the risk that Claude Code may use parent-caller inheritance (semantics B: sub-agents inherit `plan-orchestrate`'s explicit sonnet). Under B, unpinned reviewers would silently downgrade to sonnet — unacceptable for review depth. Pinning fable removes the ambiguity: reviewers always run at ceiling regardless of harness precedence rules.

## [0.4.7] — 2026-07-05

Align with the new fleet model-tiering rule: verify/security/final-judge stages **inherit** from session, no explicit override. Session ceiling controls their tier — fable when the operator is on fable, opus when on opus, etc.

- **inherit (was fable):** `codegraph-reviewer`, `graphiti-reviewer`, `security-quorum`, `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor`, `pre-commit-adversarial-pass`. The `model:` line is removed from each frontmatter — Task dispatch inherits the parent session model.

**Why the revert:** the `~/claude-skills-central/rules/model-tiering.md` rule (added 2026-07-05, auto-loaded fleet-wide) explicitly states that verify/security/final-judge stages should NOT carry a model override — the operator's session tier is the ceiling. v0.4.6 pinned these to `fable` which zeroed that flexibility (opus-session runs would still burn fable on reviews). Per the rule, cheap writers + expensive skeptics = skeptics inherit the current expensive tier, they don't hard-code one.

**HCF-upstream (local drift, will re-drift on next `plugin update hcf@hcf`):** `hcf/agents/devils-advocate.md` — `model: fable` line removed → inherit. Recommend the operator run session on fable (or opus + effort xhigh) when a plan-critique or security-quorum fires and pay the cost from the ceiling, not the pin.

**Untouched from v0.4.6:** `skills/wire` stays at `model: sonnet` (installer, not review — explicit tier is correct there per rule's "sonnet for writing code"). Non-review agents unchanged.

## [0.4.6] — 2026-07-04

Fable-era model targeting: review agents PROMOTED to fable, non-review paths held at sonnet/haiku. Assumes the operator runs the session on fable as the main orchestrator.

- **→ fable (7 review agents):** `codegraph-reviewer`, `graphiti-reviewer`, `security-quorum`, `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor`, `pre-commit-adversarial-pass`. Deep judgment on impact analysis, historical conflict detection, security consensus, and last-chance adversarial pass — fable's reasoning depth pays back the per-call cost when it catches issues that opus would miss.
- **`skills/wire/SKILL.md`** — explicit `model: sonnet` added so `/pb-hcf:wire` no longer inherits the session model (previously would run on fable when the operator was in fable mode — wasted spend on a playbook installer).

**HCF-upstream review agents NOT touched:** `devils-advocate` and `standards-enforcer` remain at opus. Local override would drift on the next `plugin update hcf@hcf`. Recommend upstream PR: promote `devils-advocate` to fable (post-plan critique is exactly the review depth fable is worth); leave `standards-enforcer` at opus (structured rule check, doesn't need fable).

**Non-review tiers unchanged:** `tdd-worker` (sonnet — many invocations), 4 retrieval/templated agents (sonnet), 2 mechanical agents (haiku). Ceiling read of "fable for planning + review only" would have left the review agents at opus; assignment read (this release) makes them USE fable.

## [0.4.5] — 2026-07-02

Model tier optimization across the bundled agents — sonnet/haiku where reasoning depth is not the bottleneck, opus preserved everywhere judgment matters. Cuts per-plan token spend without weakening the review/security gates.

- **→ haiku (2):** `pre-flight-check` (yes/no artefact + branch + probe check, deterministic), `post-commit-verify-handoff` (prints an ASCII box with a slash command, purely mechanical).
- **→ sonnet (4):** `pre-plan-graphiti-recall`, `post-plan-manual-test-plan`, `pre-implementation-incident-recall`, `post-commit-build-summary` — structured retrieval + templated output; sonnet handles cleanly and `pre-implementation-incident-recall` fires per-task so the cost multiplier compounds.
- **opus kept (7):** `codegraph-reviewer`, `graphiti-reviewer`, `security-quorum`, the 3 security specialists (`security-static-analyst` / `security-adversarial-tester` / `security-defensive-auditor`), `pre-commit-adversarial-pass`. All judgment-heavy — dropping tier here loses signal.

**Not touched (upstream HCF):** `devils-advocate` (opus, kept), `standards-enforcer` (opus, could drop to sonnet upstream), `tdd-worker` (sonnet, kept). HCF is `markshust/hcf`; local edits would drift on plugin update — recommend the standards-enforcer drop go via upstream PR instead.

**Not touched (skills):** `hcf:plan-create` is deliberately session-model bound — swap the session to fable before invoking, back to opus after (or use the `UserPromptSubmit` fable-reminder hook shipped in `~/claude-skills-central/hooks/` fleet-wide).

## [0.4.4] — 2026-07-01

**Requires:** HCF ≥ 2.0.0 (frontmatter-based hook enrollment; `.claude/pipeline.md` retired).

verify-feature contract wired into the post-plan agent — task files now carry the slug/test_name binding that tdd-worker honors at implementation time.

- **`agents/post-plan-manual-test-plan.md`** — new Step 4.5: after writing `.claude/test-plans/<ticket>.yml`, APPEND a `## Verify-feature contract` block to every per-task plan file (`.claude/plans/<plan-name>/NNN-*.md`) whose Requirements back a story with `spec_file` set + `manual_only: false`. Block carries the exact `story_slug` / `test_name` / `spec_file` triple plus the wrap instruction. Idempotent — re-running the agent replaces existing contract blocks rather than appending duplicates.
- **STATUS: PASS** output now reports a `Contracts:` line counting patched task files.
- **`README.md`** — new `## Requirements` section makes the HCF ≥ 2.0.0 hard dependency explicit (prior mentions were prose-only). Documents the install order: `hcf@hcf` → `/hcf:project-setup` → `pb-hcf@pb-hcf` → `/pb-hcf:wire --enable-all`.

**Why:** without this, `/proxiblue-skills:verify-feature` aborted at pre-flight because YAML story slugs never appeared as `// @story: <slug>` in any spec file — the tdd-worker had no signal at spec-authoring time that the contract existed. Pairs with `pb-hcf-playwright-tdd v0.4.0`, which teaches `testing.md` how to honor the block this agent writes.
