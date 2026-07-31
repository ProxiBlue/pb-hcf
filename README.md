# pb-hcf

Full custom-workflow integration for HCF v2.0.0+ via the new frontmatter-based hook pipeline. Ships 14 agents enrolled at 7 hook points (`pre-plan` / `post-plan` / `pre-implementation` / `post-batch` / `post-implementation` / `pre-commit` / `post-commit`) that together cover everything the legacy `/proxiblue-skills:workflow-build-feature` wrapper did, plus the v0.5.0 verification spine — pre-flight checks, branch warnings, Graphiti recall, prospective failure analysis, manual test-plan posting, per-task incident recall + constitution injection, structural + historical + mutation + security review, runtime error triage against Bugsink, adversarial final scan (incl. rector-diff judgment), verify-feature handoff, build-complete summary, and pipeline-firing audit. After v0.4.0 the wrapper skill is obsolete: vanilla `/hcf:plan-create` + `/hcf:plan-orchestrate` execute the entire custom workflow because every step is a hook agent. Two skills round out the workflow: `/pb-hcf:interview` (pre-plan clarity-scored scope builder) and `/pb-hcf:modernization-sweep` (bounded apply-mode rector for existing code).

> **HCF v2.0.0 compatibility (2026-06-26).** HCF dropped `.claude/pipeline.md`. Agents now declare hook membership via YAML frontmatter (`phase:` / `order:` / `mode:`) — see [HOOKS.md upstream](https://github.com/markshust/hcf#pipeline). `/pb-hcf:wire` enrolls bundled agents by stamping that frontmatter into `.claude/agents/<name>.md` overrides only when `--enable=<name>` is passed (default: off). `--enable-all` enrolls every bundled agent for the full workflow. If a legacy `.claude/pipeline.md` exists, `/pb-hcf:wire` refuses to run and points the user at `/hcf:project-update` to migrate first.

## Requirements

- **[HCF](https://github.com/markshust/hcf) ≥ 2.0.0** — hard dependency. pb-hcf is a companion plugin; it ships agents, playbooks, and a wire installer, but the plan-create / plan-orchestrate / hook-dispatch harness comes from HCF itself. Every agent enrolled by `/pb-hcf:wire` targets one of HCF v2's 8 frontmatter-declared hook points (`pre-plan` / `post-plan` / `pre-implementation` / `pre-batch` / `post-batch` / `post-implementation` / `pre-commit` / `post-commit`) — without HCF loaded, those hooks never fire and the enrolled agents stay dormant.

  Install and configure HCF **before** installing pb-hcf:

  1. `/plugin install hcf@hcf`
  2. `/hcf:project-setup` (creates `.claude/CLAUDE.md`, `.claude/testing.md`, `.claude/code-standards.md`, `.claude/architecture.md`).
  3. `/plugin install pb-hcf@pb-hcf`
  4. `/pb-hcf:wire --enable-all` (or `--enable=<name>[,<name>]` for a curated subset).

  Legacy pre-v2.0.0 HCF is **not** supported — `/pb-hcf:wire` refuses to run when `.claude/pipeline.md` (the pre-v2 registry) is present and points the operator at `/hcf:project-update` to migrate.

## What's in the plugin

### Skills

| Name | What |
|---|---|
| `/pb-hcf:wire` | Multi-playbook installer + opt-in HCF v2 hook enrollment. Discovers `templates/playbooks/*.md`, copies each to `.claude/<name>.md`, appends a single fenced section to `.claude/CLAUDE.md`, writes `.claude/wires.json` registry, runs per-domain reachability probes. With `--enable=<name>[,<name>]` (or `--enable-all`), copies the named bundled agent(s) to `.claude/agents/<name>.md` with `phase`/`order`/`mode` stamped per the default-enrollment table. |
| `/pb-hcf:interview` | Pre-plan clarity-scored scope builder. Interviews the user one question at a time (Harper Reed pattern), scores the emerging spec across Goal / Constraints / Success Criteria / Context (0–5 each), refuses handoff to `/hcf:plan-create` below threshold 16/20. Auto-triggers on vague build asks — no explicit invocation required. |
| `/pb-hcf:modernization-sweep` | Apply-mode rector for **existing** custom Magento code. Exactly one module × one ruleset per invocation off the ordered ladder (`UP_TO_PHP_83` → code-quality → type-declaration → dead-code), own `modernize/<module>-<set>` branch, dirty-tree + protected-branch refusals, post-apply idempotency dry-run, module unit tests, then hands off to the standard review chain. Never merges itself. Designed as bounded, ralph-loop-friendly grind work; tracks progress in `.claude/modernization-state.json`. |

### Enrollable agents (default-off; opt in via `--enable=<name>` or `--enable-all`)

| Name | Hook | Order | Mode | What it does |
|---|---|---|---|---|
| `pre-flight-check` | `pre-plan` | 5 | single | Verifies onboarding artifacts (`.claude/CLAUDE.md`, `.claude/testing.md`, `.claude/wires.json`, pb-hcf fence). Loops `wires.json` probes. **Refuses to run on protected branches** (`live` / `uat` / `main` / `master`). WARNs (not BLOCKs) if `.claude/constitution.md` is missing. Returns PASS / WARN / BLOCK — BLOCK aborts plan-create. |
| `pre-plan-graphiti-recall` | `pre-plan` | 10 | single | Extracts topic keywords from the user's feature request, searches Graphiti (`search_memory_facts` + `search_nodes`) across `[project-id, fleet]` group_ids, returns Historical Context block with cited episode UUIDs — prior decisions, past incidents, vendor verdicts, planned-but-not-built. Guarantees foresight before HCF Phase 1 Discovery runs. |
| `pre-mortem` | `post-plan` | 20 | single | Assumes the freshly created plan ALREADY FAILED in production and works backwards to the most plausible causes, ranked by likelihood × blast radius, then verifies each against the plan's task requirements as CONFIRMED-COVERED or UNCOVERED. Distinct lens from `devils-advocate` (gap-finding forward from the plan vs failure-backwards from an assumed incident). Runs after `devils-advocate` (10), before `post-plan-manual-test-plan` (50). |
| `post-plan-manual-test-plan` | `post-plan` | 50 | single | After `devils-advocate` (HCF bundled, order 10), mines `_plan.md` + per-task Requirements, derives user stories, posts a phased GH ticket comment (via `gh-comment-hidden.sh` helper — caveman + minimised as off-topic per fleet rule), writes `.claude/test-plans/<ticket>.yml` per [SCHEMA.md](../../proxiblue-skills/skills/manual-test-plan/SCHEMA.md). |
| `pre-implementation-incident-recall` | `pre-implementation` | 10 | single | For each `_task-NNN.md`, identifies the touched module/area, searches Graphiti for prior incidents, PREPENDS a `## Prior incidents in this area` section to the task file. Also copies `.claude/constitution.md` into the plan dir as `_constitution.md` (once, idempotently) — the first point in the pipeline where the plan dir provably exists. tdd-workers read both during their normal task ingestion — institutional memory + project invariants arrive in worker context automatically. |
| `issue-sentinel` | `post-batch` | 30 | single | Queries the central Bugsink error tracker for issues `first_seen` since this batch started (project + `HCF_RELEASE` filtered), triages via bricklayer `diagnose-error` where wired, returns PASS or structured PUSHBACK with `friendly_id` + stacktrace excerpt + suspected file:line. Falls back to a thin `var/report` + cron-stderr scan when Bugsink is unreachable. Writes a `_issue_sentinel.md` verdict to the plan dir every batch. First agent enrolled at pb-hcf's new `post-batch` hook point. |
| `codegraph-reviewer` | `post-implementation` | 30 | single | Diff-impact review via pb-codegraph code graph. Surfaces indirect callers grep misses (Magento plugins, observers wired in `events.xml`, DI preferences, layout overrides). Returns PASS / PUSHBACK with `mcp__pb-codegraph__impact` citations. |
| `graphiti-reviewer` | `post-implementation` | 40 | single | Diff-vs-knowledge-graph review — historical counterpart of codegraph-reviewer. Catches: change that conflicts with a prior decision, change that recreates a fixed incident pattern, new dependency that violates a vendor verdict, change overlapping planned-but-not-built work. Returns PASS / PUSHBACK with cited graphiti episode UUIDs. |
| `mutation-tester` | `post-implementation` | 45 | single | Tests-that-test-the-tests. Runs Infection mutation testing on the plan's changed PHP files only (`app/code/**`, excluding generated/vendor/fixtures), gates on a min-MSI threshold, returns PASS or PUSHBACK listing each surviving mutant (file:line + mutator) so tdd-workers strengthen assertions instead of gaming coverage. Writes a `_mutation_tester.md` verdict every run. Runs once on the whole plan diff, after `graphiti-reviewer` (40), before `standards-enforcer` (50). |
| `security-quorum` | `post-implementation` | 70 | single | 3-agent 2-of-3 security consensus orchestrator. Spawns the 3 specialists in parallel, runs 2-round consensus, synthesises a single PASS / FAIL / NEEDS-REVIEW verdict, writes one verdict episode to graphiti. ~$0.30–1.00 per run. |
| `pre-commit-adversarial-pass` | `pre-commit` | 10 | single | One last adversarial-tester pass on the staged diff AFTER the full test suite passes, BEFORE the commit lands. Looks for last-minute regressions, exploit patterns, attack chains, dependency CVEs in version bumps, and judges `scripts/rector-check.sh`'s contested transforms (public signature changes, dead-code removal near DI/observer wiring, constructor changes) against Magento-wiring risk. Returns PASS or DEFER (advisory — does NOT block commit; surfaces to the build-summary). Read-only. |
| `post-commit-verify-handoff` | `post-commit` | 10 | single | Prints the fresh-thread instruction that hands off to `/verify-feature <ticket>` (skill convention requires fresh thread so verify's TodoWrite doesn't fight the build's). Unmissable ASCII box. |
| `post-commit-build-summary` | `post-commit` | 20 | single | Prints the BUILD COMPLETE summary aggregating every hook verdict + per-task review outcomes + deferred concerns + branch/commit info + `READY TO DEPLOY` (or `NOT READY TO DEPLOY` if any gate blocked). Final user-facing checkpoint before `/deploy-check`. |
| `pipeline-audit` | `post-commit` | 90 | single | After orchestration completes, proves which enrolled pipeline phases actually fired vs silently skipped. Mechanizes the hcf-build-integration-gaps lesson (built-but-never-fired integrations). Derives the expected-agent list from `.claude/wires.json` enrollments, maps each to a documented evidence artefact, posts a PASS/FAIL verdict via chatroom MCP (else writes `_pipeline_audit.md` in the plan dir). Runs last — tail of the post-commit hook, after every other post-commit agent — so any artefact another agent wrote already exists on disk. |

### Library agents (spawned BY security-quorum at runtime — not enrollable)

| Name | Role within the trio |
|---|---|
| `security-static-analyst` | Reads code, traces data flows from sources to sinks. Cites file:line. Uses codegraph impact + graphiti incident recall. |
| `security-adversarial-tester` | Hostile-actor angle. Builds exploit payloads + attack chains. Online CVE lookups (NVD, GitHub Advisory DB, OSV). |
| `security-defensive-auditor` | Pass-then-verify discipline. Walks each framework-provided defense (Magento ACL, form_key, escapeHtml, CSP, crypto) and confirms it fires correctly. |

### Playbook templates (installed by `/pb-hcf:wire` to `.claude/<name>.md`)

| Name | Authority scope |
|---|---|
| `templates/playbooks/codegraph.md` | Code-structure / caller / impact questions (pb-codegraph MCP usage). |
| `templates/playbooks/graphiti.md` | Discussion / decision / intent / planned-but-not-built questions (Graphiti MCP usage + 5-step search discipline). |
| `templates/playbooks/security.md` | OWASP / vulnerability assessment + 3-specialist quorum 2-of-3 rule. |
| `templates/playbooks/bricklayer.md` | Runtime-resolved truth (DI preferences, merged plugin chains, live EAV, actual DB schema, error triage) via the `inchoo/magento-bricklayer` MCP. Probe-gated install — only copied when `vendor/bin/bricklayer` is detected (see wire's bricklayer probe). |
| `templates/playbooks/playwright.md` (future) | E2E test design and coverage. |

### Other templates (not installed by wire — copy/consume directly)

| Name | What |
|---|---|
| `templates/constitution.md` | Immutable project-invariants template. Installed once by `/pb-hcf:wire` (install-without-overwrite) to `.claude/constitution.md`; then copied unmodified into every plan dir as `_constitution.md` by `pre-implementation-incident-recall`. |
| `templates/rector/rector.php.dist` + `templates/rector/README.md` | PHP 8.3 modernization convention: code-quality + type-declaration + dead-code rector sets, custom-namespace paths placeholder, Magento-plugin-safety `withSkip()` list. Consumed by `scripts/rector-check.sh`, `pre-commit-adversarial-pass`, and `/pb-hcf:modernization-sweep`. Install via the README; wire adds a `@rector.php` pointer to the `.claude/CLAUDE.md` fence. |
| `templates/infection/infection.json5.dist` + `templates/infection/README.md` | Infection mutation-testing config consumed by `mutation-tester` — scoped source dirs, min-MSI / min-covered-MSI floors, JSON log path the agent parses for file:line + mutator PUSHBACK entries. |
| `templates/sentry/README.md` | Per-project install doc for `justbetter/magento2-sentry` — the Sentry-SDK-compatible module that reports runtime errors into central Bugsink so `issue-sentinel` has something to query. |
| `templates/otel/otel.env.dist` + `services/otel/README.md` | Claude Code OTLP telemetry: client-side env template (`CLAUDE_CODE_ENABLE_TELEMETRY`, `OTEL_METRICS_EXPORTER`, `OTEL_EXPORTER_OTLP_ENDPOINT`, per-project resource attributes) + collector options doc (SigNoz / Langfuse / plain otel-collector, mirror-of-bugsink singleton pattern). Docs + env only in 0.5.0 — no collector implementation ships yet. |
| `docs/release-tagging.md` | The `HCF_RELEASE=<plan-name>#<batch-n>` convention — how Bugsink events and `magento2-sentry` releases get tagged so `issue-sentinel` can scope queries to "this batch". |
| `scripts/rector-check.sh` | Deterministic dry-run gate: rector against changed `app/code/**/*.php` files only, non-empty proposed-transform diff = exit 1. Documented for `post-batch` / `pre-commit` use; consumed as structured input by `pre-commit-adversarial-pass`. |

## Authority scope model

Each playbook declares — at the top, as a fixed section — what it is the source of truth for and what it explicitly defers to siblings. This avoids contradictory guidance when multiple playbooks are wired together. When adding a new playbook, copy the existing `## Authority scope` skeleton and fill in the matching defer-to lines.

## HCF v2 hook integration

HCF v2.0.0 (released 2026-06-26) replaced the central `.claude/pipeline.md` registry with **agent-frontmatter enrollment**. Every agent file — plugin-shipped or project-local — opts into the pipeline by declaring three YAML keys:

```yaml
---
name: codegraph-reviewer
description: "..."
model: opus
tools: Read, Glob, Grep, Bash, mcp__pb-codegraph__impact
# --- hook enrollment ---
phase: post-implementation   # one of 8 hooks (see table below)
order: 30                    # lower runs first; default 100
mode: single                 # "single" | "batch"; default "single"
---
```

### The 8 hook points

| Hook | Fires |
|---|---|
| `pre-plan` | Before `plan-create` Phase 1 (Discovery) begins |
| `post-plan` | `plan-create` Phase 6, after dependency validation |
| `pre-implementation` | `plan-orchestrate` after Step 2, before the first batch |
| `pre-batch` | Each loop iteration, before workers spawn |
| `post-batch` | Each loop iteration, after results collected |
| `post-implementation` | `plan-orchestrate` Step 4a, when all tasks are complete |
| `pre-commit` | Step 4a, after the full test suite passes, before the commit |
| `post-commit` | Step 4a, after the commit, before the push/PR prompt |

### Discovery routine HCF runs at each hook

At each hook firing, HCF:
1. Globs `.claude/agents/*.md` (project-local) and `$HCF_PLUGIN/agents/*.md` (and every other installed plugin's `agents/`, including pb-hcf's).
2. Merges by `name` — **a local file overrides the plugin file entirely** (no field-level merge).
3. Filters to agents whose `phase` equals the current hook.
4. Sorts by `order` ascending, then by `name` (case-insensitive) for ties.
5. Spawns each in order; `mode: single` runs one subagent for the whole plan, `mode: batch` splits files into batches of ~10 and runs parallel subagents.

If the filtered set is empty → silent no-op (no narration, no work, no spawn). An empty hook is invisible.

### How pb-hcf integrates

pb-hcf does **not** modify HCF's source. Two integration surfaces:

| Surface | What pb-hcf writes | Where it goes | When |
|---|---|---|---|
| Playbook files | Domain rule docs (codegraph, graphiti, security, …) referenced from a fenced section in `.claude/CLAUDE.md` | `.claude/<playbook>.md` (project-local, host-RW) | Every `/pb-hcf:wire` run — playbooks are passive context, no opt-in needed |
| Agent enrollments | Plugin agent body with `phase` / `order` / `mode` stamped into frontmatter | **Resolved target directory** (auto-detected from `.ddev/docker-compose*.yaml` mount; falls back to project-local `.claude/agents/`; override via `--target=<path>`) | Only when `--enable=<name>[,<name>]` (or `--enable-all`) is passed to `/pb-hcf:wire` |

**Target-directory resolution respects RO-mount fleet design.** Most ProxiBlue projects mount `~/claude-code-magento-agents/` RO at `/var/www/html/.claude/agents/` so containerized agents can't modify gatekept config. Wire auto-detects this mount, writes to the host-side source (`~/claude-code-magento-agents/`) where it IS writable, and HCF discovery in the container reads what landed there RO. Gatekeeping intact: only host can change enrollments.

For projects without that mount pattern, wire falls back to project-local `.claude/agents/`. Detection order: `--target=<path>` flag → docker-compose mount source → project-local fallback.

**Fleet-wide vs per-project semantics.** When the target is a shared central dir (the ProxiBlue fleet default), enrolling an agent applies to every project that mounts the same source. Per-project granularity is achieved at the mount layer (which projects mount it), not at the wire layer. If a project needs to differ, point its mount at a project-specific dir and run wire with `--target=<that-path>`.

Result: bundled agents live in the plugin without a `phase` (dormant in plugin source). They are *visible* to `Task` but *dormant* in the pipeline. Enrollment is one explicit gesture — fleet-wide via the shared mount, or per-project via `--target`. Idempotent: re-runs skip silently when an agent is already enrolled with the expected phase.

### Default enrollment knobs (stamped when `--enable=<name>` is passed)

| Agent | `phase` | `order` | `mode` | Rationale |
|---|---|---|---|---|
| `pre-flight-check` | `pre-plan` | `5` | `single` | Fail fast — verify state + branch BEFORE any planning work begins |
| `pre-plan-graphiti-recall` | `pre-plan` | `10` | `single` | After pre-flight clears; runs once before Phase 1 Discovery so historical context lands in plan-create's window |
| (HCF) `devils-advocate` | `post-plan` | `10` | `single` | HCF bundled — runs first at post-plan to review the plan |
| `pre-mortem` | `post-plan` | `20` | `single` | After devils-advocate; assumes the plan already failed and works backwards to causes — distinct lens from gap-finding, so it runs as its own pass rather than merged into devils-advocate's |
| `post-plan-manual-test-plan` | `post-plan` | `50` | `single` | After devils-advocate + pre-mortem finish (gives the reviewed plan to mine); higher order = runs later |
| `pre-implementation-incident-recall` | `pre-implementation` | `10` | `single` | Once before first batch — pre-seeds every task file with relevant prior incidents, copies `.claude/constitution.md` into the plan dir |
| `issue-sentinel` | `post-batch` | `30` | `single` | Once per batch, after results collected — asks Bugsink what fired at runtime that the test suite never observed |
| `codegraph-reviewer` | `post-implementation` | `30` | `single` | Structural-impact review FIRST — before style fixes and security audit |
| `graphiti-reviewer` | `post-implementation` | `40` | `single` | Historical/decisional review SECOND — symmetric to codegraph on the knowledge axis |
| `mutation-tester` | `post-implementation` | `45` | `single` | THIRD — tests-that-test-the-tests, after the structural/historical reviews but before standards-enforcer reformats anything |
| (HCF) `standards-enforcer` | `post-implementation` | `50` | `batch` | HCF bundled — code-standards fixes; opt-in (HCF ships with phase commented) |
| `security-quorum` | `post-implementation` | `70` | `single` | Security audit LAST at post-implementation, on the final diff including standards-enforcer fixes |
| `pre-commit-adversarial-pass` | `pre-commit` | `10` | `single` | One last adversarial scan after tests pass, before commit. Read-only. Returns PASS or DEFER. |
| `post-commit-verify-handoff` | `post-commit` | `10` | `single` | Prints verify-feature handoff first (the loud unmissable block) |
| `post-commit-build-summary` | `post-commit` | `20` | `single` | Then prints the aggregated BUILD COMPLETE summary |
| `pipeline-audit` | `post-commit` | `90` | `single` | LAST — tail of the pipeline, so every other agent's evidence artefact already exists on disk to audit for |

To pick a different hook for an agent (e.g. per-batch cadence instead of per-plan for codegraph-reviewer), edit the project's `.claude/agents/<name>.md` after wire — change `phase` to `post-batch`. The wire respects local edits on re-run (won't clobber a `phase` you've changed; warns instead).

### Why pipeline.md is dead in v2

HCF v2 actively gates `plan-create` and `plan-orchestrate` while `.claude/pipeline.md` exists (via SessionStart notice + PreToolUse + UserPromptExpansion hooks under HCF). `/hcf:project-update` is the migrator — it parses any active entries in pipeline.md, copies the relevant plugin agents to `.claude/agents/`, stamps the right frontmatter, and removes the file. Once removed, the gates open.

`/pb-hcf:wire` mirrors that gate: it refuses to run while `pipeline.md` exists, with a message pointing the user at `/hcf:project-update` first. This prevents accidental coexistence (and prevents the wire from ever writing the file that would brick the planning workflow).

## How HCF flows change with pb-hcf wires

Vanilla HCF is a complete flow on its own. pb-hcf doesn't replace it — pb-hcf gives HCF's existing agents better tools (codegraph + graphiti MCP context) and adds a security quorum at HCF's native `post-implementation` hook (enrolled via agent frontmatter; default off). HCF source files are not modified.

The two side-by-side diagrams below cover the user-visible flow. Everything pb-hcf adds is annotated with `◄── pb-hcf`.

### Vanilla HCF (no pb-hcf wires)

```
User: "build feature X"
  │
  ▼
/hcf:plan-create
  ├─ Phase 1: Discovery (codebase glob + read; permutation brainstorm)
  ├─ Phase 2: Grounded Clarification (ask user)
  ├─ Phase 3: Define _plan.md
  ├─ Phase 4: Break down into per-task .md files
  ├─ Phase 5: Validate dependencies
  ├─ Phase 6: Post-plan pipeline (devils-advocate — grep-only)
  ├─ Phase 7: User reviews plan
  └─ Phase 8: Finalize
  │
  ▼
/hcf:plan-orchestrate <plan>
  ├─ Spawn parallel tdd-workers per task:
  │     ├─ RED → GREEN → REFACTOR
  │     └─ Run FULL project test suite per task
  ├─ Loop until all tasks complete
  └─ Post-implementation pipeline:
        ├─ standards-enforcer over the diff
        └─ Full test suite again
        ▼
        Single final commit
```

Wired by default: `standards-enforcer` in post-implementation. That's it. No graphiti consultation, no codegraph consultation, no security audit, no prior-decision recall.

### Adjusted process (pb-hcf v0.4.0 wired — 100% via HCF v2 hooks)

```
User runs /proxiblue-skills:workflow-onboard-project   ◄── ONE TIME per project
  │
  ├─ Install plugins: pb-hcf, pb-hcf-playwright-tdd, proxiblue-skills, hyva-ai-tools
  ├─ /hcf:project-setup → .claude/CLAUDE.md
  ├─ /pb-hcf-playwright-tdd:setup → .claude/testing.md
  └─ /pb-hcf:wire --enable-all   ◄── pb-hcf v0.4.0: enrolls ALL 10 bundled agents
        ├─ Drops .claude/{codegraph,graphiti,security}.md (playbooks)
        ├─ Single fenced section in .claude/CLAUDE.md pointing to all playbooks
        ├─ Runs reachability probes (pb-codegraph health, mcp__graphiti__get_status)
        ├─ For each of 10 bundled agents:
        │     copies $PLUGIN/agents/<name>.md → .claude/agents/<name>.md
        │     stamps phase / order / mode in frontmatter
        └─ Writes .claude/wires.json registry (playbooks[] + enrollments[])


User runs /hcf:plan-create   ◄── VANILLA — no wrapper skill needed
  │
  ├─ pre-plan hook (HCF v2 — frontmatter discovery):
  │   ├─ pb-hcf: pre-flight-check (order 5)
  │   │   ├─ Verifies onboarding artifacts present
  │   │   ├─ Loops .claude/wires.json — probes every entry
  │   │   ├─ Checks git branch — BLOCKs if on live/uat/main/master
  │   │   └─ Returns PASS / WARN / BLOCK (BLOCK aborts plan-create)
  │   │
  │   └─ pb-hcf: pre-plan-graphiti-recall (order 10)
  │       ├─ Extracts topic keywords from user's feature request
  │       ├─ Searches graphiti [project, fleet] — both indexes, 4-synonym discipline
  │       └─ Returns Historical Context block (cited episode UUIDs)
  │
  ├─ Phase 1: Discovery (vanilla HCF)
  ├─ Phase 2: Grounded Clarification (vanilla HCF — asks user)
  ├─ Phase 3-5: Define plan, break into tasks, validate deps (vanilla HCF)
  │
  ├─ post-plan hook (HCF v2):
  │   ├─ HCF: devils-advocate (order 10) — auto-consults wired playbooks via CLAUDE.md
  │   └─ pb-hcf: post-plan-manual-test-plan (order 50)
  │       ├─ Mines _plan.md Success Criteria + per-task Requirements
  │       ├─ Derives user stories per SCHEMA.md
  │       ├─ Writes .claude/test-plans/<ticket>.yml
  │       └─ Posts phased GH ticket comment (caveman + minimised off-topic)
  │
  ├─ Phase 7: User reviews plan
  └─ Phase 8: Finalize


User runs /hcf:plan-orchestrate <plan>   ◄── VANILLA — no wrapper skill needed
  │
  ├─ pre-implementation hook (HCF v2):
  │   └─ pb-hcf: pre-implementation-incident-recall (order 10)
  │       ├─ Per task: extract touched module/area from _task-NNN.md
  │       ├─ Search graphiti [project, fleet] for prior incidents
  │       └─ PREPEND "## Prior incidents in this area" to each _task-NNN.md
  │           → tdd-workers read it during normal task ingestion
  │
  ├─ Implementation loop (per batch):
  │   ├─ pre-batch hook (vanilla HCF — empty unless project enrolls more)
  │   ├─ Spawn parallel tdd-workers (HCF native)
  │   │     ├─ Workers see "Prior incidents" section in task file
  │   │     ├─ RED → GREEN → REFACTOR (HCF native)
  │   │     └─ Targeted tests per .claude/testing.md scoping
  │   └─ post-batch hook (vanilla HCF — empty unless project enrolls more)
  │
  ├─ post-implementation hook (HCF v2 — runs ONCE at plan-end):
  │   ├─ pb-hcf: codegraph-reviewer (order 30)
  │   │   └─ Structural impact of whole diff via pb-codegraph code graph
  │   ├─ pb-hcf: graphiti-reviewer (order 40)
  │   │   └─ Historical/decisional impact of whole diff via Graphiti knowledge graph
  │   ├─ HCF: standards-enforcer (order 50 — opt-in via frontmatter)
  │   └─ pb-hcf: security-quorum (order 70)
  │       ├─ Round 1 parallel spawn of 3 specialists:
  │       │   ├─ security-static-analyst (data-flow + file:line)
  │       │   ├─ security-adversarial-tester (payloads + CVE lookup)
  │       │   └─ security-defensive-auditor (pass-then-verify controls)
  │       ├─ Round 2 parallel re-spawn with sibling votes (revise)
  │       ├─ Verdict synthesis (2-of-3 rule, dissents preserved)
  │       └─ Write ONE verdict episode to graphiti
  │
  ├─ Full test suite runs ONCE (HCF native invariant — must pass before commit)
  │
  ├─ pre-commit hook (HCF v2):
  │   └─ pb-hcf: pre-commit-adversarial-pass (order 10)
  │       ├─ One adversarial sweep of staged diff (git diff --cached)
  │       ├─ Three angles: worst input / indirect-call-chain / CVE-in-bumped-dep
  │       └─ Returns PASS or DEFER (advisory — never blocks commit)
  │
  ├─ Single final commit (HCF native)
  │
  └─ post-commit hook (HCF v2):
      ├─ pb-hcf: post-commit-verify-handoff (order 10)
      │   └─ Prints unmissable ASCII box: "open fresh thread, run /verify-feature <NNN>"
      └─ pb-hcf: post-commit-build-summary (order 20)
          └─ Aggregates plan / hook verdicts / per-task outcomes / branch state
              Prints BUILD COMPLETE summary + READY/NOT-READY-TO-DEPLOY footer


[USER ACTION — fresh thread] /verify-feature <ticket>
[USER ACTION] /deploy-check <target> when satisfied


ALWAYS-ON (per session, via pb-graphiti hooks):
  ├─ SessionStart hook   — graphiti recall ([project, fleet] or [host, fleet])
  ├─ TaskCompleted hook  — Claude Code task → graphiti episode (3-cap)
  ├─ SubagentStop hook   — every Task spawn return → graphiti episode (2-cap)
  ├─ SessionEnd hook     — session terminate → graphiti episode (8-cap)
  └─ PreCompact hook     — rarely fires on 1M context; still wired for smaller models
```

**Note the absence of `/proxiblue-skills:workflow-build-feature` in the flow.** Every step that skill used to orchestrate now lives in an HCF hook. Running plain `/hcf:plan-create` + `/hcf:plan-orchestrate` triggers the entire custom workflow because hook discovery is automatic — the user can never forget to run the wrapper. The skill becomes deletable once every project is wired with `--enable-all` (or whichever enrollment subset they prefer).

### Side-by-side per-phase

| HCF phase | Vanilla | With pb-hcf wires | Net change |
|---|---|---|---|
| Onboard | Manual install per project | One workflow chains plugin installs + wire + setup | More automation, one entry point |
| Pre-flight before plan | None | Loop `wires.json` registry, probe each playbook's MCP | Stop early if stack broken |
| plan-create Phase 1 Discovery | Codebase glob + brainstorm | + graphiti recall for planned/discussed/prior-decisions + codegraph impact | Foresight gap closed — plan considers future-intent |
| plan-create Phase 6 devils-advocate | Grep-only review | + codegraph indirect-caller chase + graphiti adjacent-work + security scope flag | Multi-source critique |
| plan-orchestrate workers | grep + read | + codegraph find_symbol/impact + graphiti incident recall | Workers consult institutional memory |
| plan-orchestrate worker tests | Full project suite per task | Targeted scoped tests per task (testing.md) | Avoids parallel-collision when project's testing.md is configured for it — see "Open concerns" |
| plan-orchestrate post-implementation | standards-enforcer (dormant by default in HCF v2) | + codegraph-reviewer (order 30) + security-quorum (order 70), both enrolled via `/pb-hcf:wire --enable=...` | Real security gate that scales |
| Test suite at plan-end | Full suite | Full suite (unchanged from vanilla) | — |
| Commit | Single commit at plan-end | Single commit at plan-end | Unchanged |
| Session lifecycle writes to graphiti | None | SessionStart recall + TaskCompleted / SubagentStop / SessionEnd consolidation | Long-term memory accumulates |

### What's gained vs vanilla HCF

| Capability | How |
|---|---|
| Foresight on plan creation (planned/discussed features influence current design) | graphiti search in plan-create Phase 1 |
| Indirect-caller awareness in plan-review + workers | codegraph impact via wire |
| Prior-incident recall when implementing | graphiti search in tdd-worker per task |
| Multi-source critique by devils-advocate | three playbooks consulted simultaneously |
| Multi-agent security gate with quorum (2-of-3) | `security-quorum` agent enrolled at HCF `post-implementation` hook |
| Verdict provenance preserved across runs | `security-quorum` writes one episode per audit; next audit sees it |
| Pre-flight stack health check (scales to N wires) | `wires.json` registry loop (includes `enrollments[]`) |
| Session-decision capture | SubagentStop + SessionEnd hooks (pb-graphiti) |
| No parallel-dev work vs HCF | All extensions via context + project-local agent overrides; HCF source untouched |
| Authority Scope hygiene | Each playbook declares its truth domain — no contradictory guidance |

### Open concerns

These are real trade-offs the design accepts. Revisit when they bite in practice.

**Per-task review granularity.** `codegraph-reviewer` enrolls at HCF's `post-implementation` hook, which fires once at batch-end, not after every task. If a tdd-worker introduces a regression in task 3 of 5, the reviewer surfaces it only after task 5 finishes — slower feedback than a per-task gate would give. (HCF's `post-batch` hook fires per batch; if the per-batch cadence matters more than per-task, switch the agent's `phase` to `post-batch` in `.claude/agents/codegraph-reviewer.md`.) The trade is that no HCF wrapping is needed; HCF source stays clean.

**Parallel-test resource collision.** HCF defaults run the full project test suite at end of each `tdd-worker` task AND again in post-implementation. Under parallel worker dispatch this can collide on shared MariaDB rows, Redis cache, OpenSearch indexes, Playwright sessions, `var/` artefacts. Mitigation lives in each project's `.claude/testing.md` — scope test commands to targeted invocation (per-file / per-testsuite) rather than full-suite, so workers don't all hit the whole DB. Or run with `--max-parallel 1` if the project's HCF supports it.

### When NOT to use pb-hcf wires

- **Non-Magento project, no graphiti corpus.** `/hcf:plan-orchestrate` direct is fine.
- **Quick spike / throwaway code.** Wiring adds discipline that costs ~$0.30-1.00 per plan; not worth it for a 10-line experiment.
- **Pre-release security sign-off.** Use a heavier full-OWASP quorum (e.g. `/agent-teams team_security` from the proxiblue-skills central catalogue) — `security-quorum` is the per-plan gate, not the release-readiness audit.

## What pb-hcf is NOT

- **Not a wrapper for HCF flows.** No `plan-create` / `plan-orchestrate` substitution. Every custom step lives in an HCF v2 hook agent that HCF discovers via frontmatter — vanilla HCF commands trigger the full workflow.
- **Not a clone of HCF.** All HCF source files (agents, skills) stay upstream-clean.
- **Not a marketplace.** Lives as a single plugin; install via the standard plugin marketplace flow.
- **Does not touch `.claude/pipeline.md`.** That file is legacy in HCF v2.0.0+ — `/hcf:project-update` is the only thing allowed to migrate or remove it. `/pb-hcf:wire` refuses to run while it exists.
- **`/proxiblue-skills:workflow-build-feature` is obsolete after v0.4.0** for projects enrolled with `--enable-all`. The skill stays in the proxiblue-skills marketplace for transitional use but every step it orchestrated has a hook-enrolled equivalent. New projects should skip the wrapper entirely.

## Adding a new playbook

1. Write `templates/playbooks/<name>.md`. First section MUST be `## Authority scope` declaring what this playbook owns + what it defers to siblings.
2. Add a probe row to `skills/wire/SKILL.md` (`Per-playbook reachability probes` table) if the domain has a probeable MCP / service.
3. Bump pb-hcf version, commit, push.
4. Re-run `/pb-hcf:wire` in each project to pick up the new playbook.

No other plugin needs to change. Wire registry auto-discovers; CLAUDE.md fence auto-rewrites with a pointer for the new playbook; pre-flight checks pick it up via `wires.json`.

## Troubleshooting — "hook fires empty even though I enrolled agents"

**Symptom:** `/hcf:plan-create` or `/hcf:plan-orchestrate` reports `Phase N (<hook>) — EMPTY hook → fast-path skip` for a hook where you stocked agents via `/pb-hcf:wire --enable` (and the files visibly exist in your target dir).

**Cause:** HCF v2's hook discovery routine is described in HOOKS.md as instructions for the LLM, not as code. The in-session Claude implements discovery by improvising a bash enumeration script on the fly. That improvised script can have syntax bugs. Confirmed in PPS test 2026-06-30: invalid `for f in $LOC/*.md 2>/dev/null` (redirect placement wrong) crashed enumeration at line 35. Partial output from earlier sections was consumed as ground truth; the project-local `.claude/agents/` glob never ran; Claude concluded "no agents at any hook" → empty fast-paths everywhere.

**Diagnose deterministically:**

```bash
# Run from project root, in container OR host:
"$CLAUDE_PLUGIN_ROOT/scripts/discover-hooks.sh"

# Or pin the target explicitly:
"$CLAUDE_PLUGIN_ROOT/scripts/discover-hooks.sh" --target=~/claude-code-magento-agents

# Or filter to one hook:
"$CLAUDE_PLUGIN_ROOT/scripts/discover-hooks.sh" --hook=pre-plan
```

The script enumerates your `.claude/agents/` (auto-detected from `.ddev/docker-compose*.yaml` mount source, with project-local fallback), awk-parses `phase` / `order` / `mode` from each .md's YAML frontmatter, and prints the resolved-order table HCF *should* produce. If this script lists your agents and HCF's plan-create still reports empty — that's the bash-crash failure mode.

**Fix at use-time (workaround):**

pb-hcf v0.4.2+ ships a SessionStart hook (`hooks/discover-hooks.sh`) that auto-runs the discovery on session start and injects the resolved table into Claude's context window. With this in place, HCF's plan-create reads the discovery from context instead of improvising bash — failure mode bypassed entirely. **Verify the hook fired** by checking your session's initial system context for "pb-hcf hook enrollment discovery".

If the SessionStart hook didn't fire (e.g. older pb-hcf version, plugin not loaded yet at session start), force discovery manually in the plan-create prompt:

```
Before Phase 1 Discovery, execute the HOOKS.md Discovery Routine for the `pre-plan` hook LITERALLY:
1. Run: `ls .claude/agents/*.md` from project root — confirm file list.
2. For each, awk-parse YAML frontmatter, extract `phase:` value.
3. Filter to agents whose phase equals "<HOOK>".
4. Print the resolved-order line BEFORE spawning.
5. Spawn each via Task in order.
If step 3 yields ZERO, STOP and paste the frontmatter of the missing files.
```

**Upstream:** filed against [markshust/hcf](https://github.com/markshust/hcf) proposing HCF ship its own deterministic `hooks/discover-hooks.sh` so plan-create can call it instead of relying on LLM-improvised bash. Until that's merged, the pb-hcf SessionStart hook is the workaround that keeps the failure mode from hitting HCF's downstream users.

## Upgrading existing projects (from pb-hcf v0.2.x → v0.3.0)

Existing pb-hcf-wired projects fall into three states. Pick the matching recipe.

**Discover the state for any project (run from project root):**

```bash
[ -f .claude/pipeline.md ]   && echo "legacy pipeline.md PRESENT"   || echo "no pipeline.md"
[ -f .claude/wires.json ]    && echo "pb-hcf wired"                 || echo "not wired"
grep -l "pb-hcf:start"     .claude/CLAUDE.md 2>/dev/null && echo "pb-hcf fence present"
grep -l "pb-git[n]exus:start" .claude/CLAUDE.md 2>/dev/null && echo "legacy code-graph wire fence (will be auto-migrated)"
ls .claude/agents/*.md 2>/dev/null && echo "project-local agents exist"
```

### State A — legacy `pipeline.md` present (typical for older HCF+pb-hcf projects)

1. **Update HCF to v2.0.0+ first** (in container or wherever the project's Claude Code runs):
   ```
   /plugin update hcf@hcf
   ```
2. **Update pb-hcf to v0.3.0+**:
   ```
   /plugin update pb-hcf@pb-hcf
   ```
3. **Migrate pipeline.md** — `/hcf:project-update` parses pipeline.md, copies any actively-enrolled agents (uncommented `- <name>` entries) into `.claude/agents/<name>.md` with `phase` stamped, and deletes the file:
   ```
   /hcf:project-update
   ```
   This already handles pb-hcf's `codegraph-reviewer` / `security-quorum` correctly via HCF's discovery routine — they get copied into `.claude/agents/` if they were uncommented in pipeline.md.
4. **Re-run wire** to refresh `wires.json` (now includes `enrollments[]`):
   ```
   /pb-hcf:wire
   ```
5. **Verify**:
   ```bash
   ls .claude/pipeline.md 2>&1   # should say no such file
   cat .claude/wires.json | jq '.playbooks, .enrollments'
   ls .claude/agents/            # any frontmatter-stamped overrides land here
   ```

### State B — already-on-frontmatter project that was never pb-hcf-wired

(Project ran `/hcf:project-update` already, has no pipeline.md, but no `.claude/wires.json`.)

```
/plugin update pb-hcf@pb-hcf
/pb-hcf:wire --enable=codegraph-reviewer        # or --enable-all for Magento + security-sensitive
```

### State C — fresh project (no HCF, no pb-hcf)

```
/hcf:project-setup
/pb-hcf:wire --enable=codegraph-reviewer        # add ,security-quorum or use --enable-all if needed
```

### Verifying what HCF will actually run

After any state's recipe, confirm HCF's discovery routine sees the right agents.

**For ProxiBlue fleet projects (mount-pattern wired):**

```bash
# Resolved enrollment target from wires.json
jq -r '.enrollmentTarget' .claude/wires.json

# What's enrolled, by phase (run on host — that's where the target lives)
TARGET=$(jq -r '.enrollmentTarget' .claude/wires.json)
for f in "$TARGET"/*.md; do
  [ -f "$f" ] || continue
  phase=$(awk '/^---$/{f=!f;next}f&&/^phase:/{print $2}' "$f")
  [ -n "$phase" ] && echo "$(basename "$f")  →  $phase"
done | sort
```

**For projects without the fleet mount (project-local fallback):**

```bash
for f in .claude/agents/*.md; do
  [ -f "$f" ] || continue
  phase=$(awk '/^---$/{f=!f;next}f&&/^phase:/{print $2}' "$f")
  [ -n "$phase" ] && echo "$(basename "$f")  →  $phase"
done | sort
```

Or trust the printed resolved-order line HCF logs at each hook firing.

## What the wire does NOT do during upgrade

- **Never edits `pipeline.md`.** Migration is HCF's job (`/hcf:project-update`). If pipeline.md is present, wire halts. No exceptions.
- **Never silently enrolls agents.** Even on an upgrade re-run, agents land in the enrollment target only via `--enable=<name>`. The exception is `/hcf:project-update`, which re-creates enrollments that were active in pipeline.md (so behaviour is preserved across the migration).
- **Never overwrites an existing enrollment-target `<name>.md` with a different `phase`.** If you've intentionally moved `codegraph-reviewer` to `post-batch`, re-running `--enable=codegraph-reviewer` warns and leaves your edit alone.
- **Never writes to a non-writable target.** If the resolved target is owned by another user (typical for root-owned mount sources) or doesn't exist, wire aborts with the path and a suggested `chown` / `mkdir` fix — it does NOT escalate to sudo.
- **Never touches non-pb-hcf content in a shared central target.** The `~/claude-code-magento-agents/` directory hosts more than just pb-hcf agents (e.g. the magento-agents library subdirs); wire only manages files matching pb-hcf bundled agent names. Other content is left alone.

## Status

| Version | What landed |
|---|---|
| v0.1.0 | codegraph-reviewer agent + codegraph.md playbook + graphiti.md playbook + multi-playbook `wire` skill. |
| v0.2.0 | Security quorum: `security-quorum` orchestrator + 3 specialist agents + `security.md` playbook. 2-of-3 consensus, ~$0.30-1.00 per run. |
| v0.3.0 | **BREAKING — aligned with HCF v2.0.0.** Wire no longer writes `.claude/pipeline.md` (that file blocks HCF planning in v2). Replaced with opt-in HCF v2 hook enrollment via agent frontmatter: `/pb-hcf:wire --enable=<name>[,<name>]` (or `--enable-all`) copies the named bundled agent to `.claude/agents/<name>.md` with `phase: post-implementation` + `order` + `mode` stamped. Wire halts if a legacy `pipeline.md` is present. `wires.json` gains `enrollments[]`. Graphiti playbook adds search-discipline guidance. |
| v0.4.0 | **100% HCF v2 hook migration — `/proxiblue-skills:workflow-build-feature` made obsolete.** Ships **8 new agents** covering every step the wrapper used to orchestrate, each enrolled at the appropriate HCF v2 hook: `pre-flight-check` (pre-plan, order 5 — verifies onboarding + warns on protected branches `live`/`uat`/`main`/`master`), `pre-plan-graphiti-recall` (pre-plan, order 10 — historical context before Discovery), `post-plan-manual-test-plan` (post-plan, order 50 — derives + posts manual test plan + writes YAML), `pre-implementation-incident-recall` (pre-implementation, order 10 — per-task graphiti prior-incident lookup, prepends to task files), `graphiti-reviewer` (post-implementation, order 40 — historical/decisional diff review symmetric to codegraph-reviewer), `pre-commit-adversarial-pass` (pre-commit, order 10 — last-chance adversarial sweep on staged diff, advisory only), `post-commit-verify-handoff` (post-commit, order 10 — unmissable fresh-thread handoff to /verify-feature), `post-commit-build-summary` (post-commit, order 20 — aggregated BUILD COMPLETE with READY/NOT-READY-TO-DEPLOY). Wire skill agent table expanded to 10 enrollable agents. `--enable-all` enrolls every bundled agent. `codegraph-reviewer` body updated for HCF v2 post-implementation protocol (no more wrapper-era PLAN_NAME/TASK_NUMBER inputs). |
| v0.4.1 | **RO-mount-respecting enrollment target.** Wire's `--enable` no longer assumes project-local `.claude/agents/` is writable — for fleet-mounted projects (ProxiBlue ddev pattern with `~/claude-code-magento-agents:/var/www/html/.claude/agents:ro`) it would silently fail because the mount source is the actual write target. New target-resolution: `--target=<path>` flag → auto-detect from `.ddev/docker-compose*.yaml` mount source → project-local fallback. Wire writes from host to the resolved target (respecting RO-mount gatekeeping intent — container view stays read-only, only host can change enrollments). Idempotency tightened: re-enrolling an agent already present with the expected `phase` is a silent no-op (no diff prompt). Library agents (3 security specialists) ride along when `security-quorum` is enrolled. `wires.json` gains `enrollmentTarget` + `enrollmentTargetSource` fields. |
| v0.4.2 | **Deterministic hook discovery + SessionStart auto-inject.** Fixes the "hook fires empty even though agents are stocked" failure mode (confirmed PPS 2026-06-30: HCF's plan-create asks Claude to improvise a bash glob; the improvised script had invalid `for f in $LOC/*.md 2>/dev/null` redirect placement, crashed at line 35, partial output read as ground truth → all hooks fired empty). Ships `scripts/discover-hooks.sh` (deterministic awk-based enumeration with `--target` / `--hook` / `--json` flags, auto-detects mount source from .ddev/docker-compose) + `hooks/discover-hooks.sh` (SessionStart hook that auto-runs the script and injects the resolved per-hook agent table into Claude's session context so plan-create never needs to improvise discovery). Bypasses the LLM-improvised-bash failure mode entirely. README troubleshooting section added. Upstream issue filed against markshust/hcf (#4) proposing HCF ship its own deterministic discover-hooks.sh so the workaround can be retired. |
| v0.4.3 | **Container-side target detection fix.** v0.4.2's `discover-hooks.sh` auto-detect parsed `.ddev/docker-compose*.yaml` for the mount source (e.g. `~/claude-code-magento-agents`) — correct on host where that path exists, but wrong inside the container where the same agents are visible at `.claude/agents/` via the RO mount and the host path is meaningless. Updated detection order: (1) `--target=<path>` flag → (2) project-local `.claude/agents/` if it exists and has .md files (container-correct via the RO mount) → (3) docker-compose mount source only if the detected host path actually exists on disk → (4) project-local fallback. Lets the same script run correctly on both host and container. SessionStart hook now works end-to-end inside the DDEV container. |
| v0.4.4–v0.4.9 | Model-tiering iteration (haiku/sonnet/opus assignment across bundled agents, several rounds of reviewer-tier flip-flopping settling on session-inherit for review agents) + the verify-feature contract wired into `post-plan-manual-test-plan`. See `CHANGELOG.md` for the per-version detail. |
| v0.5.0 | **Verification spine — 4 new enrollable agents, a new `post-batch` hook point, plan-quality + test-quality + runtime-error + pipeline-proof coverage.** Ships `pre-mortem` (post-plan, order 20 — prospective failure analysis, assumes the plan failed and works backwards to causes, distinct lens from devils-advocate), `mutation-tester` (post-implementation, order 45 — Infection mutation testing on changed PHP files, PASS/PUSHBACK on min-MSI + surviving mutants, tests-that-test-the-tests), `issue-sentinel` (**new `post-batch` hook point**, order 30 — queries central Bugsink for issues since batch start, triages via bricklayer `diagnose-error`, thin-log fallback), `pipeline-audit` (post-commit, order 90 — proves which enrolled phases actually fired this run vs silently skipped, mechanizing the hcf-build-integration-gaps lesson). Wire's enrollable-agent table grows to **14 agents at 7 hook points**; `--enable-all` enrolls all 14. Also ships: bricklayer playbook template (probe-gated install, runtime-resolved-truth authority, codegraph cross-reference for resolution-disagreement arbitration) + wire's bricklayer probe; project constitution template (`templates/constitution.md`, install-without-overwrite by wire, injected into every plan dir as `_constitution.md` by `pre-implementation-incident-recall`, checked — WARN only — by `pre-flight-check`); `/pb-hcf:interview` skill (clarity-scored pre-plan scope builder, Harper Reed one-question-at-a-time pattern, 16/20 threshold gate); central Bugsink wire probe (200-or-401-is-reachable, DSN-presence check) + `docs/release-tagging.md` (`HCF_RELEASE=<plan-name>#<batch-n>` convention) + `templates/sentry/README.md` (`justbetter/magento2-sentry` per-project install); `templates/rector/` (PHP 8.3 modernization ruleset + Magento-plugin-safety skip list) + `scripts/rector-check.sh` (deterministic changed-files dry-run gate, non-zero exit on proposed transforms) + `pre-commit-adversarial-pass` extended with a rector-diff judgment step (contested transforms near plugin/observer/DI wiring get file:line risk citations); `/pb-hcf:modernization-sweep` skill (apply-mode rector for existing code, one module × one ruleset per bounded ralph-loop-friendly run, own branch, never self-merges); `templates/otel/otel.env.dist` + `services/otel/README.md` (Claude Code OTLP telemetry client env + collector-options doc — docs/env only, no collector implementation yet). |

Next planned playbook: `playwright.md` — folds in E2E test design and coverage guidance.
